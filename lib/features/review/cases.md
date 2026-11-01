I used plain SQLite with hand-written models, so there is no build_runner step. You can swap in drift later by changing only the repositories.

How it works
Quiz player: case_view.dart shows one case with checkbox answers, then a correction after “Valider”. Choices are multi-select with strict scoring, so the selection must match the correct set exactly. Both the catalog quiz and the review session use this one widget.
Server decides the schedule: the server chooses which cards are due and when each returns, so the website and the app stay in sync. The app downloads the due cards with their full content, so a session works offline.
Offline answers: answer_queue.dart saves every answer to SQLite first, then sends it to the server in batches. Each answer carries a unique client_id, so the server can ignore duplicates if a response is lost.
When sync happens: after each answer, when a session loads, and at logout.
Session start: a session starts online when the server is reachable, and from the last cached cards otherwise.
Data wipe: logout and account deletion clear all local data, so the next user never sees someone else’s cards.

