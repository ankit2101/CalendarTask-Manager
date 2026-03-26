import Anthropic from '@anthropic-ai/sdk';
import { ActionItem, NormalizedEvent } from '../../../shared/types/calendar';
import { tokenStore } from '../auth/token-store';

let clientInstance: Anthropic | null = null;

async function getClient(): Promise<Anthropic> {
  if (clientInstance) return clientInstance;

  const apiKey = await tokenStore.loadSecret('claude-api-key');
  if (!apiKey) {
    throw new Error('Claude API key not configured. Please add it in Settings.');
  }

  clientInstance = new Anthropic({ apiKey });
  return clientInstance;
}

export function resetClaudeClient(): void {
  clientInstance = null;
}

export async function extractActionItems(
  note: string,
  event: NormalizedEvent
): Promise<ActionItem[]> {
  const client = await getClient();

  const start = new Date(event.start);
  const end = new Date(event.end);
  const durationMinutes = Math.round((end.getTime() - start.getTime()) / 60000);

  const prompt = `You are an assistant that extracts action items from meeting notes.

Meeting: "${event.title}"
Date: ${start.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
Duration: ${durationMinutes} minutes
Attendees: ${event.attendees.join(', ') || 'Not specified'}

Meeting notes:
${note}

Extract all action items from these notes. Return ONLY a JSON object with this exact structure:
{
  "actionItems": [
    {
      "id": "1",
      "title": "short actionable title (verb + object)",
      "description": "additional context or null",
      "dueDate": "YYYY-MM-DD or null",
      "assignee": "name or email if mentioned, or null",
      "priority": "urgent | important | normal"
    }
  ]
}

Rules:
- Only extract explicit commitments, tasks, and follow-ups — not general discussion points
- Titles must be action-oriented (start with a verb: "Send", "Schedule", "Review", "Create", etc.)
- If no action items, return {"actionItems": []}
- Infer due dates only when clearly stated ("by Friday", "next Monday", "EOD", "end of week")
- Today is ${start.toISOString().split('T')[0]}
- Set priority "urgent" only for explicit deadlines within 24 hours or words like "ASAP", "urgent", "critical"
- Set priority "important" for items marked important or needed soon (this week)
- Default to "normal" for everything else
- Return valid JSON only, no markdown, no surrounding text`;

  const message = await client.messages.create({
    model: 'claude-opus-4-5',
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  });

  const content = message.content[0];
  if (content.type !== 'text') {
    throw new Error('Unexpected response type from Claude');
  }

  // Strip markdown code fences if the model wraps the response despite instructions
  const raw = content.text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/i, '').trim();
  const parsed = JSON.parse(raw);
  const items: ActionItem[] = parsed.actionItems ?? [];

  // Ensure IDs are unique
  return items.map((item, idx) => ({
    ...item,
    id: item.id ?? String(idx + 1),
  }));
}
