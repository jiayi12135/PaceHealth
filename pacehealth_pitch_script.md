## PaceHealth — Pitch Script (~3 min)

**[The issue]**
Most fitness apps track your progress but don't actually adapt when your plan isn't working. You fill out a questionnaire once, get a plan, and that's it — even if you keep skipping the same workout for the same reason, the app just keeps handing you the same routine. Static plans ignore missed workouts, injuries, and lifestyle changes. Many also completely ignore the menstrual cycle, even though it directly affects training capacity for a huge chunk of users.

That's the gap PaceHealth closes — we use AI to continuously adapt fitness and nutrition recommendations based on what a user actually does, not just what they said in a form once.

**[What it does]**
It starts with personalized onboarding — goals, injuries, equipment, experience level, preferred workout days — and the AI generates a personalized weekly workout plan from that.

The plan is adaptive: once a week's sessions are done, PaceHealth automatically generates the next week's plan, adjusting based on what was actually completed or skipped, and why.

Workouts run through guided sessions — a swipe-through exercise interface with built-in timing, and if a session looks unusual, it captures quick feedback in the moment.

That feeds a workout calendar and tracking view: full workout history alongside the current week's plan, tracking completed, skipped, and incomplete sessions — and it automatically marks any workout you never acted on as incomplete, so nothing falls through the cracks.

Progress reports track your weight trend and goal progress, estimate weeks remaining, and the AI summarizes it in plain language — including explaining patterns in missed sessions.

Alongside that, AI nutrition support generates personalized meal plans, recognizes ingredients from food photos, and tracks calories and macros.

Then period-aware coaching predicts menstrual cycle phases and adapts coaching tone and workout suggestions accordingly.

We also built a context-aware AI coach — chat-based guidance that uses your real workout and adherence history for personalized responses.

And the home progress dashboard ties it together visually — a goal-progress tracker estimating time to goal based on workouts you've actually completed, not just time passed.

**[How it was built]**
On the tech side: Flutter for a single cross-platform frontend, FastAPI for the backend REST API, Supabase for database and auth, and Anthropic's Claude API for everything AI-driven — plan generation, chat, meal planning, and report summaries. One rule we stuck to throughout: every number the user sees — progress percentage, weeks to goal, weight change — is computed in code. The AI only turns those already-correct numbers into natural language; it never invents a statistic. Exercise images come from the Pexels API.

**[Close]**
So PaceHealth isn't just a tracker — it's a plan that learns from you, week over week, and actually tells you why things are or aren't working.
