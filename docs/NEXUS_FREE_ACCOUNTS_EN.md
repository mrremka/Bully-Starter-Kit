# Nexus Mods: free accounts

Bully Starter Kit **does not bypass Nexus Mods restrictions**.

For a free account, **Slow Download** is the recommended mode. Starter Kit opens the official Nexus file page, the user clicks `Manual Download` → `Slow Download`, and the app detects the ZIP in Downloads, validates it, and continues setup.

If the user selected **Auto** and Nexus returns `403 Forbidden`, setup does not fail: the UI switches to Slow Download and continues through the official free flow.

If the browser saves to a non-standard folder, the Slow Download dialog can be used to choose the ZIP manually.
