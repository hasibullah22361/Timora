// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This code is running in a Supabase Edge Function (Deno environment)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface AIRequest {
  prompt: string;
  context: string;
  history?: Array<{ role: string; content: string }>;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { prompt, context, history = [] } = (await req.json()) as AIRequest;

    const geminiApiKey = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('OPENAI_API_KEY');

    // System prompt ensuring strict JSON action payloads for automated productivity orchestration
    const systemPrompt = `You are Timora AI, the elite executive assistant and productivity coach built inside the Timora Productivity App.
You help users plan their days, organize deep focus blocks, manage habits, and execute tasks.
Always format your response with clean Markdown and include actionable, realistic suggestions.

${context ? `USER CONTEXT:\n${context}\n` : ''}

If the user request warrants creating or modifying tasks or focus sessions, return a structured JSON block at the very end of your response inside:
\`\`\`json
{
  "summary": "Brief explanation of proposed changes",
  "confidence": "high",
  "actions": [
    {
      "id": "uuid",
      "type": "createTask" | "createFocusSession" | "scheduleActivity",
      "data": { "title": "...", "priority": "high", "durationSeconds": 1800 }
    }
  ]
}
\`\`\``;

    // Call LLM API (Google Gemini or fallback provider)
    let aiContent = "";
    if (geminiApiKey) {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [
              { role: 'user', parts: [{ text: systemPrompt }] },
              ...history.map((h) => ({
                role: h.role === 'assistant' ? 'model' : 'user',
                parts: [{ text: h.content }],
              })),
              { role: 'user', parts: [{ text: prompt }] },
            ],
          }),
        }
      );

      const data = await response.json();
      aiContent = data?.candidates?.[0]?.content?.parts?.[0]?.text || "I've structured your productivity roadmap.";
    } else {
      // Fallback local deterministic synthesis
      aiContent = `Here is your optimized productivity plan based on your current focus goals and active tasks:\n\n` +
        `• 🌅 **Morning Focus**: Priority execution block\n` +
        `• ☀️ **Afternoon Sprint**: Deep work deliverable\n` +
        `• 🌙 **Evening Review**: Habit tracking & wind-down reflection\n\n` +
        `\`\`\`json\n` +
        `{\n` +
        `  "summary": "Generated personalized productivity schedule",\n` +
        `  "confidence": "high",\n` +
        `  "actions": [\n` +
        `    { "id": "act_1", "type": "createTask", "data": { "title": "Priority Deep Work Sprint", "priority": "high" } }\n` +
        `  ]\n` +
        `}\n` +
        `\`\`\``;
    }

    return new Response(
      JSON.stringify({
        content: aiContent,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});
