declare const alert: (message?: any) => void;

declare type Timeout = ReturnType<typeof setTimeout>;
declare type Interval = ReturnType<typeof setInterval>;

declare module Global {
  var __DEV__: boolean;
}
