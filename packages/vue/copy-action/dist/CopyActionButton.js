import { defineComponent, h, mergeProps, } from 'vue';
import { useCopyAction } from './useCopyAction';
export const CopyActionButton = defineComponent({
    name: 'CopyActionButton',
    inheritAttrs: false,
    props: {
        copyValue: {
            type: String,
            required: true,
        },
        idleLabel: {
            type: String,
            default: 'Copy',
        },
        successLabel: {
            type: String,
            default: 'Copied',
        },
        failureLabel: {
            type: String,
            default: 'Copy failed',
        },
        resetDelay: {
            type: Number,
            default: 1800,
        },
        resetOnMouseleave: {
            type: Boolean,
            default: true,
        },
        ariaLabel: {
            type: String,
            default: '',
        },
    },
    emits: {
        copied: () => true,
        failed: () => true,
        reset: (_state) => true,
    },
    setup(props, { attrs, emit, slots }) {
        const { state, label, copy, reset } = useCopyAction({
            value: () => props.copyValue,
            idleLabel: props.idleLabel,
            successLabel: props.successLabel,
            failureLabel: props.failureLabel,
            resetDelay: props.resetDelay,
        });
        async function handleClick() {
            const copied = await copy();
            if (copied) {
                emit('copied');
                return;
            }
            emit('failed');
        }
        function handleMouseleave() {
            if (!props.resetOnMouseleave || state.value === 'idle') {
                return;
            }
            const previousState = state.value;
            reset();
            emit('reset', previousState);
        }
        return () => h('button', mergeProps(attrs, {
            type: 'button',
            class: ['iterlife-copy-action', attrs.class],
            'data-copy-state': state.value,
            'aria-label': props.ariaLabel || props.idleLabel,
            onClick: handleClick,
            onMouseleave: handleMouseleave,
        }), slots.default
            ? slots.default({ label: label.value, state: state.value })
            : [h('span', { class: 'iterlife-copy-action__label' }, label.value)]);
    },
});
