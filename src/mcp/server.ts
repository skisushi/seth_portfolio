import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

import {
  acmeCorpPolicy,
  sarahChen,
  scenario1Proposal,
  scenario2Proposal,
} from '../domain/mock-data.js';
import {
  checkPolicyCompliance,
  searchTravelOptions,
  getPreferenceScore,
} from './tools.js';
import type { TripChangeProposal, FlightOption, HotelOption } from '../domain/types.js';

const server = new Server(
  { name: 'veyant', version: '1.0.0' },
  { capabilities: { resources: {}, tools: {} } }
);

// ─── RESOURCES ────────────────────────────────────────────────────────────────

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: 'traveler://sarah-chen/profile',
      name: 'Sarah Chen — Traveler Profile',
      description: 'Full traveler profile: loyalty accounts, preferences, home airport',
      mimeType: 'application/json',
    },
    {
      uri: 'trip://london-sept/details',
      name: 'London Trip — September 2024',
      description: 'Current trip segments for both Scenario 1 and Scenario 2',
      mimeType: 'application/json',
    },
    {
      uri: 'policy://acme-corp/rules',
      name: 'Acme Corp — Travel Policy',
      description: 'Corporate travel policy: rate limits, cabin rules, approval thresholds, market exceptions',
      mimeType: 'application/json',
    },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  if (uri === 'traveler://sarah-chen/profile') {
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(sarahChen, null, 2),
        },
      ],
    };
  }

  if (uri === 'trip://london-sept/details') {
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(
            {
              traveler: 'Sarah Chen',
              trip: 'Boston to London, September 2024',
              scenario1: {
                description: 'London meeting extended by one day',
                proposal: scenario1Proposal,
              },
              scenario2: {
                description: 'NYC stopover added on the way home',
                proposal: scenario2Proposal,
              },
            },
            null,
            2
          ),
        },
      ],
    };
  }

  if (uri === 'policy://acme-corp/rules') {
    return {
      contents: [
        {
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(acmeCorpPolicy, null, 2),
        },
      ],
    };
  }

  throw new Error(`Unknown resource: ${uri}`);
});

// ─── TOOLS ───────────────────────────────────────────────────────────────────

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'check_policy_compliance',
      description:
        'Evaluates a proposed trip change against Acme Corp travel policy. Returns pass/fail per rule, market exception handling, and whether manager approval is required.',
      inputSchema: {
        type: 'object',
        properties: {
          proposal: {
            type: 'object',
            description: 'TripChangeProposal — segments, totalAdditionalCost, and primary market',
            properties: {
              segments: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    type: { type: 'string', enum: ['flight', 'hotel'] },
                    supplier: { type: 'string' },
                    rate: { type: 'number' },
                    cabin: { type: 'string' },
                    upgradeApplied: { type: 'boolean' },
                    city: { type: 'string' },
                  },
                  required: ['type', 'supplier', 'rate'],
                },
              },
              totalAdditionalCost: { type: 'number' },
              market: { type: 'string', description: 'Primary market for exception lookup e.g. London' },
            },
            required: ['segments', 'totalAdditionalCost', 'market'],
          },
        },
        required: ['proposal'],
      },
    },
    {
      name: 'search_travel_options',
      description:
        'Search available flights or hotels from the Veyant supplier catalog. Filter by type and optionally by route (flights) or city (hotels).',
      inputSchema: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: ['flight', 'hotel'], description: 'Type of travel option to search' },
          origin: { type: 'string', description: 'IATA airport code for flight origin e.g. LHR' },
          destination: { type: 'string', description: 'IATA airport code for flight destination e.g. BOS' },
          city: { type: 'string', description: 'City name for hotel search e.g. London' },
        },
        required: ['type'],
      },
    },
    {
      name: 'get_preference_score',
      description:
        "Scores a flight or hotel option against Sarah Chen's personal travel preferences. Returns a 0–100 score and a breakdown of factors (carrier preference, seat type, loyalty benefits, etc.).",
      inputSchema: {
        type: 'object',
        properties: {
          option: {
            type: 'object',
            description: 'A FlightOption or HotelOption from the supplier catalog',
          },
        },
        required: ['option'],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'check_policy_compliance') {
    const proposal = args?.proposal as TripChangeProposal;
    const result = checkPolicyCompliance(proposal);
    return {
      content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
    };
  }

  if (name === 'search_travel_options') {
    const results = searchTravelOptions({
      type: args?.type as 'flight' | 'hotel',
      origin: args?.origin as string | undefined,
      destination: args?.destination as string | undefined,
      city: args?.city as string | undefined,
    });
    return {
      content: [{ type: 'text', text: JSON.stringify(results, null, 2) }],
    };
  }

  if (name === 'get_preference_score') {
    const option = args?.option as FlightOption | HotelOption;
    const result = getPreferenceScore(option);
    return {
      content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
    };
  }

  throw new Error(`Unknown tool: ${name}`);
});

// ─── START ────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
