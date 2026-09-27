---
title: Tournament mode
description: run synchronized play across multiple clients
order: 30
---

Tournament mode lets several inso clients begin the same map together. It is intended for LAN events and streams where each display needs to stay in sync.

## start the clients

On each computer, open the same map and start the client in tournament mode:

```text
inso --tournament songs/my-map/
```

The path is required in tournament mode because the client has no map-selection fallback there. Use the same `.osu` file or map folder on every client. The map is loaded and prepared before the start signal arrives, and each client will display a wait screen while listening for UDP packets on port `8727`.

Allow inbound UDP traffic on port `8727` through each client's firewall. The default target IP is `255.255.255.255`; use the broadcast address for the local subnet if needed.

## send a start signal

Run `inso_lan_broadcast` on a computer that can reach the clients:

```text
inso_lan_broadcast start
inso_lan_broadcast start 192.168.1.255 500
```

The broadcaster is a separate tool from the game client. It sends only a start or abort command and does not identify the map, so verify the map and game build on every client before starting.

The wait (default `250ms`) gives the packet time to reach every client before the start is scheduled. A signal is sent four times with a short gap between packets so one lost packet does not stop the event.

Clients begin from a three-second lead-in, then synchronize the map clock with real time, in contrast to regular play, which is synchronized on audio playback clock time.

## abort a map

```text
inso_lan_broadcast abort
inso_lan_broadcast abort 192.168.1.255
```

An abort cancels a running map if an issue is found, e.g. if one or more clients failed to start. It reloads and rearms the map so the clients can prepare for another attempt.

For a local fallback, press `ctrl+enter` on a waiting client. This starts that client without sending a network signal, so it is useful for testing but not for synchronizing a group.
