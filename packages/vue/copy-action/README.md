# @iterlife/vue-copy-action

Shared Vue copy action button for IterLife frontends.

## Install

```bash
pnpm add @iterlife/vue-copy-action
```

```ts
import '@iterlife/vue-copy-action/style.css';
import { CopyActionButton } from '@iterlife/vue-copy-action';
```

## Usage

```vue
<script setup lang="ts">
import { CopyActionButton } from '@iterlife/vue-copy-action';
</script>

<template>
  <CopyActionButton copy-value="hello@example.com" />
</template>
```

## Exports

- `CopyActionButton`
- `useCopyAction`
- `@iterlife/vue-copy-action/style.css`
