# Architecture

The target structure of this repo. Code that disagrees with this doc is drift: fix the code, or change this doc through a spec (`## Architecture impact`). Keep every table current; a row that is not true today is a bug in this doc.

## Units and modules
A unit is a group of modules with one owner that changes together. Each module has one job of 5 words or fewer; a job that needs "and" is two modules.

| Unit | Module (path) | Layer | Job (≤ 5 words) |
|---|---|---|---|

## Owners
One owner per fact. Every fact, store, shared resource (a device, a port, a lock, a single-instance process) and outbound call has exactly one owning module. Others ask the owner; they never write its store or drive its resource.

| Fact / store / shared resource | Owner (only writer) | Readers |
|---|---|---|

## Outbound calls
Everything that leaves this process or machine.

| External system | Called only by | What is sent |
|---|---|---|

## Connections
Who talks to whom across units. Dependencies point one way, from entry points to logic to stores, with no cycles.

| From | To | What moves |
|---|---|---|

## Drift checks
One line per check: date, what was compared, gaps found and where they went.
-
