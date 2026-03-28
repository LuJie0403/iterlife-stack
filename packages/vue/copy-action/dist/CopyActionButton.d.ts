import { type CopyActionState } from './useCopyAction';
export declare const CopyActionButton: import("vue").DefineComponent<import("vue").ExtractPropTypes<{
    copyValue: {
        type: StringConstructor;
        required: true;
    };
    idleLabel: {
        type: StringConstructor;
        default: string;
    };
    successLabel: {
        type: StringConstructor;
        default: string;
    };
    failureLabel: {
        type: StringConstructor;
        default: string;
    };
    resetDelay: {
        type: NumberConstructor;
        default: number;
    };
    resetOnMouseleave: {
        type: BooleanConstructor;
        default: boolean;
    };
    ariaLabel: {
        type: StringConstructor;
        default: string;
    };
    minHeight: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
    minWidth: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
    paddingInline: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
    borderRadius: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
}>, () => import("vue").VNode<import("vue").RendererNode, import("vue").RendererElement, {
    [key: string]: any;
}>, {}, {}, {}, import("vue").ComponentOptionsMixin, import("vue").ComponentOptionsMixin, {
    copied: () => true;
    failed: () => true;
    reset: (_state: CopyActionState) => true;
}, string, import("vue").PublicProps, Readonly<import("vue").ExtractPropTypes<{
    copyValue: {
        type: StringConstructor;
        required: true;
    };
    idleLabel: {
        type: StringConstructor;
        default: string;
    };
    successLabel: {
        type: StringConstructor;
        default: string;
    };
    failureLabel: {
        type: StringConstructor;
        default: string;
    };
    resetDelay: {
        type: NumberConstructor;
        default: number;
    };
    resetOnMouseleave: {
        type: BooleanConstructor;
        default: boolean;
    };
    ariaLabel: {
        type: StringConstructor;
        default: string;
    };
    minHeight: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
    minWidth: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
    paddingInline: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
    borderRadius: {
        type: (StringConstructor | NumberConstructor)[];
        default: string;
    };
}>> & Readonly<{
    onCopied?: (() => any) | undefined;
    onFailed?: (() => any) | undefined;
    onReset?: ((_state: CopyActionState) => any) | undefined;
}>, {
    idleLabel: string;
    successLabel: string;
    failureLabel: string;
    resetDelay: number;
    resetOnMouseleave: boolean;
    ariaLabel: string;
    minHeight: string | number;
    minWidth: string | number;
    paddingInline: string | number;
    borderRadius: string | number;
}, {}, {}, {}, string, import("vue").ComponentProvideOptions, true, {}, any>;
