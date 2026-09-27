---
title: tournament mode
description: run synchronized play across multiple clients
order: 30
---

Tournament mode lets several inso clients begin the same map together. It is intended for LAN events, recordings, and streams where each display needs to stay in sync.

## start the clients

On each computer, open the same map and start the client in tournament mode:

```text
inso --tournament songs/my-map/
```

The map is loaded and prepared before the start signal arrives. Each client listens for UDP packets on port `8727`. The optional path can be omitted when the client should use its normal startup selection.

## send a start signal

Run `inso_lan_broadcast` on a computer that can reach the clients:

```text
inso_lan_broadcast start
inso_lan_broadcast start 192.168.1.255 500
```

The default target is `255.255.255.255` and the default wait is `250` ms. The wait gives the packet time to reach every client before the start is scheduled. A signal is sent four times with a short gap between packets so one lost packet does not stop the event.

Clients begin from a three-second lead-in, then use a shared wall clock while the audio follows it. This keeps separate displays aligned without making normal solo play depend on the network.

## abort a map

```text
inso_lan_broadcast abort
inso_lan_broadcast abort 192.168.1.255
```

An abort cancels a start that has not fired yet. After a map has started, it reloads and rearms the map so the clients can prepare for another attempt.

For a local fallback, press `ctrl+enter` on a waiting client. This starts that client without sending a network signal, so it is useful for testing but not for synchronizing a group.
