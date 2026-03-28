import {
  type CSSProperties,
  defineComponent,
  h,
  mergeProps,
} from 'vue';
import { useCopyAction, type CopyActionState } from './useCopyAction.js';

function normalizeCssLength(value: number | string): string {
  return typeof value === 'number' ? `${value}px` : value;
}

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
    minHeight: {
      type: [Number, String],
      default: '',
    },
    minWidth: {
      type: [Number, String],
      default: '',
    },
    paddingInline: {
      type: [Number, String],
      default: '',
    },
    borderRadius: {
      type: [Number, String],
      default: '',
    },
  },
  emits: {
    copied: () => true,
    failed: () => true,
    reset: (_state: CopyActionState) => true,
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

    function resolveVariableStyle(): CSSProperties {
      const style: CSSProperties = {};
      if (props.minHeight !== '') {
        style['--iterlife-copy-action-min-height'] = normalizeCssLength(
          props.minHeight
        );
      }
      if (props.minWidth !== '') {
        style['--iterlife-copy-action-min-width'] = normalizeCssLength(
          props.minWidth
        );
      }
      if (props.paddingInline !== '') {
        style['--iterlife-copy-action-padding-inline'] = normalizeCssLength(
          props.paddingInline
        );
      }
      if (props.borderRadius !== '') {
        style['--iterlife-copy-action-radius'] = normalizeCssLength(
          props.borderRadius
        );
      }
      return style;
    }

    return () =>
      h(
        'button',
        mergeProps(attrs, {
          type: 'button',
          class: ['iterlife-copy-action', attrs.class],
          'data-copy-state': state.value,
          'aria-label': props.ariaLabel || props.idleLabel,
          style: [attrs.style, resolveVariableStyle()],
          onClick: handleClick,
          onMouseleave: handleMouseleave,
        }),
        slots.default
          ? slots.default({ label: label.value, state: state.value })
          : [h('span', { class: 'iterlife-copy-action__label' }, label.value)]
      );
  },
});
