---
sidebar_position: 1
---

# DeltaCompress

DeltaCompress is a Roblox library to efficiently replicate tables. It calculates the difference between two tables that can be sent as a buffer.

## Installation

Add the following to your `wally.toml`:

```toml
[dependencies]
DeltaCompress = "nezuo/delta-compress@0.1.3"
```

### Supported Data

- array
- dictionary (except ones with number keys)
- string
- number
- boolean
- Vector2
- Vector3
- Vector2int16
- Vector3int16
- CFrame

To get started, visit the [Usage](/docs/Usage) page.
