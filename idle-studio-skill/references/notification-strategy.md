# Notification Strategy Reference

## Permission Request — The Most Important Decision

### When to Ask
**After the player's FIRST era advance** — and never before.

This is the single highest-value moment in the game's early experience:
- Player has just achieved something significant
- They are emotionally invested
- They have proven they want to come back
- The ask has obvious, immediate context

### How to Ask
Show a custom pre-permission screen BEFORE the iOS system prompt:

```
┌────────────────────────────────────────┐
│  🏺  Stay ahead of history              │
│                                         │
│  Get notified when:                     │
│  • Your offline income is about to cap  │
│  • A new Wonder is ready to build       │
│  • Your daily quests reset              │
│  • Alliance members send you gifts      │
│                                         │
│  We send at most 1–2 notifications/day. │
│                                         │
│  [ Enable Notifications ]               │
│  [ Maybe later ]                        │
└────────────────────────────────────────┘
```

Only after tapping "Enable Notifications" → trigger `requestAuthorization`.  
"Maybe later" → dismiss, try again at next prestige (max once per prestige).

### Never Do These
- ❌ Ask on cold launch (Day 1 opt-in rates drop from ~60% to ~15%)
- ❌ Ask before player has engaged with core loop
- ❌ Ask more than once per prestige cycle
- ❌ Send notifications before permission is granted

---

## Notification Types

All notifications in v1 are **local** (no server required). Scheduled by the app on background.

### 1. Offline Income Cap Warning
**Trigger:** 6 hours after app moves to background  
**Condition:** Player has not returned  
**Content:**  
- Title: "Your civilization is flourishing!"  
- Body: "Your builders have been busy — come collect before the coffers overflow!" (cap at 8h)  
**Repeat:** Once per background session (not recurring)

### 2. Daily Quest Reset
**Trigger:** 8:00 AM local time, every day  
**Condition:** Player has at least one uncompleted quest from previous day  
**Content:**  
- Title: "New daily quests are ready!"  
- Body: "Complete today's challenges for bonus coins and boosts."  
**Note:** If player already opened the app that morning, cancel this notification.

### 3. Weekly Event Start
**Trigger:** Monday 09:00 local time  
**Content:**  
- Title: "A new historical event begins!"  
- Body: Dynamic — e.g., "The Greek Olympics: earn 3× Culture this week. Can you claim the top prize?"  
**Cancel:** When player opens the app

### 4. Era Advance Reminder
**Trigger:** 24 hours after player unlocks an era advance requirement (has the gold) but hasn't advanced  
**Content:**  
- Title: "History awaits, [leader name]"  
- Body: "You have enough Gold to enter the [next era name]. Your civilization is ready."  
**Cancel:** When player advances the era

### 5. Alliance Gift Received
**Trigger:** When a Game Center alliance member sends a gift (polled on app resume, scheduled on background)  
**Content:**  
- Title: "A gift from your Alliance!"  
- Body: "[Player name] sent you a Resource Pack. Claim it before it expires."  
**Note:** v1 simulates this with Game Center multiplayer data; v2 may use push.

### 6. Wonder Construction Complete
**Trigger:** When a Wonder's construction timer expires while app is backgrounded  
**Content:**  
- Title: "Wonder of the World!"  
- Body: "Your [Wonder name] is complete! Come see it."  

---

## Notification Content Guidelines

- **Tone:** Warm, excited, never urgent or guilt-tripping
- **Length:** Title ≤ 40 characters, body ≤ 100 characters
- **Emoji:** 1 max per notification, optional
- **Personalization:** Use player's current era name and leader name when possible
- **Frequency cap:** Maximum 2 notifications per day per player
- **Quiet hours:** Do not schedule between 22:00 and 08:00 local time

## Scheduling Implementation Notes

All notifications use `UNUserNotificationCenter` with `UNCalendarNotificationTrigger` or `UNTimeIntervalNotificationTrigger`.

On app backgrounding:
1. Cancel all pending notifications
2. Recalculate schedule based on current state
3. Schedule relevant notifications (max 15 pending, iOS limit is 64)
4. Save scheduled notification IDs to UserDefaults

On app foregrounding:
1. Cancel offline cap warning (player is back)
2. Cancel any "you have enough gold" reminders (player can see the button)
3. Reschedule daily quest reminder for tomorrow if today's is done
