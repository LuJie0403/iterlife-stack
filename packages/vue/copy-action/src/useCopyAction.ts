import { computed, onBeforeUnmount, ref, toValue, type MaybeRefOrGetter } from 'vue';

export type CopyActionState = 'idle' | 'copied' | 'failed';

export interface UseCopyActionOptions {
  value: MaybeRefOrGetter<string>;
  idleLabel?: string;
  successLabel?: string;
  failureLabel?: string;
  resetDelay?: number;
}

export function useCopyAction(options: UseCopyActionOptions) {
  const state = ref<CopyActionState>('idle');
  let resetTimer: ReturnType<typeof setTimeout> | null = null;

  const idleLabel = options.idleLabel || 'Copy';
  const successLabel = options.successLabel || 'Copied';
  const failureLabel = options.failureLabel || 'Copy failed';
  const resetDelay = options.resetDelay ?? 1800;

  const label = computed(() => {
    if (state.value === 'copied') {
      return successLabel;
    }
    if (state.value === 'failed') {
      return failureLabel;
    }
    return idleLabel;
  });

  function clearResetTimer() {
    if (resetTimer) {
      clearTimeout(resetTimer);
      resetTimer = null;
    }
  }

  function reset() {
    clearResetTimer();
    state.value = 'idle';
  }

  function scheduleReset() {
    clearResetTimer();
    resetTimer = setTimeout(() => {
      state.value = 'idle';
      resetTimer = null;
    }, resetDelay);
  }

  async function copy() {
    const nextValue = toValue(options.value);
    if (!nextValue || typeof navigator === 'undefined' || !navigator.clipboard) {
      state.value = 'failed';
      scheduleReset();
      return false;
    }

    try {
      await navigator.clipboard.writeText(nextValue);
      state.value = 'copied';
      scheduleReset();
      return true;
    } catch {
      state.value = 'failed';
      scheduleReset();
      return false;
    }
  }

  onBeforeUnmount(() => {
    clearResetTimer();
  });

  return {
    state,
    label,
    copy,
    reset,
  };
}
