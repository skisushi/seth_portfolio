# Databricks notebook source
# MAGIC %md
# MAGIC # Veyant: Ingest Synthetic Trip History Data
# MAGIC
# MAGIC Implements US 7.1.2 — Sarah Chen seed data
# MAGIC
# MAGIC Loads the synthetic JSON trip history into the `veyant_dev.travel_data.trip_history` Delta table.
# MAGIC
# MAGIC **Source files** (uploaded to a Volume or DBFS path):
# MAGIC - `sarah_chen_full.json` — adapted from Marcus Chen, Boston-based, Delta+Marriott loyalty
# MAGIC - `executive_traveler_full.json` — Sarah Martinez (NYC-based executive)
# MAGIC
# MAGIC **Prerequisites:**
# MAGIC - Tables created via `databricks/sql/01_trip_history.sql`
# MAGIC - Source JSON files uploaded to a Unity Catalog Volume

# COMMAND ----------

import json
from datetime import datetime
from pyspark.sql import Row
from pyspark.sql.functions import lit, current_timestamp

# Configure these for your environment
TENANT_ID = "veyant-demo"
SOURCE_VOLUME = "/Volumes/veyant_dev/travel_data/seed"
SOURCE_FILES = [
    "sarah_chen_full.json",
    "executive_traveler_full.json",
]

# COMMAND ----------

def load_traveler_json(path: str) -> dict:
    """Load a traveler JSON file from a Volume path."""
    with open(path, "r") as f:
        return json.load(f)


def flatten_trip_record(traveler: dict, trip: dict) -> dict:
    """Convert one trip from the source JSON into a row for trip_history."""
    return {
        "tenant_id": TENANT_ID,
        "traveler_id": traveler["id"],
        "trip_id": trip["tripId"],
        "trip_name": trip.get("tripName"),
        "trip_type": trip.get("tripType"),
        "start_date": datetime.strptime(trip["startDate"], "%Y-%m-%d").date(),
        "end_date": datetime.strptime(trip["endDate"], "%Y-%m-%d").date() if trip.get("endDate") else None,
        "origin": trip.get("origin"),
        "destination": trip.get("destination"),
        "booked_date": datetime.strptime(trip["bookedDate"], "%Y-%m-%d").date() if trip.get("bookedDate") else None,
        "booked_by": trip.get("bookedBy"),
        "total_cost": trip.get("totalCost"),
        "currency": "USD",
        "air": trip.get("air", []),
        "hotel": trip.get("hotel", []),
        "car": trip.get("car", []),
        "ground": trip.get("ground", []),
        "calendar_events": trip.get("calendarEvents", []),
        "ingested_at": datetime.utcnow(),
        "source_system": "synthetic_v1",
    }


def flatten_traveler_record(traveler: dict) -> dict:
    """Convert traveler profile into a row for the travelers dim table."""
    profile = traveler.get("profile", {})
    return {
        "tenant_id": TENANT_ID,
        "traveler_id": traveler["id"],
        "first_name": profile.get("firstName"),
        "last_name": profile.get("lastName"),
        "email": profile.get("email"),
        "home_airport": "BOS" if profile.get("address", {}).get("city") == "Boston" else "EWR",
        "company": profile.get("employment", {}).get("company"),
        "title": profile.get("employment", {}).get("title"),
        "loyalty_accounts": [
            {
                "program": acct.get("program"),
                "account_number": acct.get("accountNumber"),
                "status": acct.get("status"),
                "points": acct.get("points") or acct.get("miles") or 0,
                "status_expires_date": (
                    datetime.strptime(acct["statusExpiresDate"], "%Y-%m-%d").date()
                    if acct.get("statusExpiresDate") else None
                ),
            }
            for acct in traveler.get("loyaltyAccounts", [])
        ],
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow(),
    }

# COMMAND ----------

# Load all source files and flatten
all_trip_rows = []
all_traveler_rows = []

for filename in SOURCE_FILES:
    path = f"{SOURCE_VOLUME}/{filename}"
    traveler = load_traveler_json(path)

    all_traveler_rows.append(flatten_traveler_record(traveler))
    for trip in traveler.get("trips", []):
        all_trip_rows.append(flatten_trip_record(traveler, trip))

print(f"Prepared {len(all_traveler_rows)} traveler rows")
print(f"Prepared {len(all_trip_rows)} trip rows")

# COMMAND ----------

# Write to Delta tables
trip_df = spark.createDataFrame(all_trip_rows)
trip_df.write.mode("append").saveAsTable("veyant_dev.travel_data.trip_history")

traveler_df = spark.createDataFrame(all_traveler_rows)
traveler_df.write.mode("append").saveAsTable("veyant_dev.travel_data.travelers")

# COMMAND ----------

# Sanity check
display(spark.sql("""
    SELECT
        traveler_id,
        COUNT(*) as trip_count,
        MIN(start_date) as earliest_trip,
        MAX(start_date) as latest_trip,
        SUM(total_cost) as total_spend
    FROM veyant_dev.travel_data.trip_history
    WHERE tenant_id = 'veyant-demo'
    GROUP BY traveler_id
"""))
