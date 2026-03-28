import { computed, onBeforeUnmount, ref, toValue } from 'vue';
export function useCopyAction(options) {
    const state = ref('idle');
    let resetTimer = null;
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
        }
        catch {
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
