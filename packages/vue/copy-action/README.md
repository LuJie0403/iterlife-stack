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

You can override size-related tokens per usage:

```vue
<CopyActionButton
  copy-value="hello@example.com"
  :min-height="42"
  :padding-inline="12"
  :border-radius="10"
/>
```

## Exports

- `CopyActionButton`
- `useCopyAction`
- `@iterlife/vue-copy-action/style.css`
