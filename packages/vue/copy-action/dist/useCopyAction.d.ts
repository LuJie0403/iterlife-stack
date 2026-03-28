import { type MaybeRefOrGetter } from 'vue';
export type CopyActionState = 'idle' | 'copied' | 'failed';
export interface UseCopyActionOptions {
    value: MaybeRefOrGetter<string>;
    idleLabel?: string;
    successLabel?: string;
    failureLabel?: string;
    resetDelay?: number;
}
export declare function useCopyAction(options: UseCopyActionOptions): {
    state: import("vue").Ref<CopyActionState, CopyActionState>;
    label: import("vue").ComputedRef<string>;
    copy: () => Promise<boolean>;
    reset: () => void;
};
