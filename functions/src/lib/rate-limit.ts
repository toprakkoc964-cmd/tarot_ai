export type ThrottleState = {
  windowStartedAtMs?: number;
  windowCount?: number;
  dayKey?: string;
  dayCount?: number;
};

export function checkAndBumpThrottle(args: {
  throttle: ThrottleState | undefined;
  nowMs: number;
  windowMs: number;
  windowLimit: number;
  dailyLimit: number;
  dayKey: string;
}): { allowed: boolean; next: Required<ThrottleState> } {
  const throttle = args.throttle ?? {};
  const windowStartedAtMs = Number(throttle.windowStartedAtMs ?? 0);
  const isCurrentWindow = args.nowMs - windowStartedAtMs < args.windowMs;
  const windowCount = isCurrentWindow ? Number(throttle.windowCount ?? 0) : 0;
  const dayCount =
    throttle.dayKey === args.dayKey ? Number(throttle.dayCount ?? 0) : 0;

  const next = {
    windowStartedAtMs: isCurrentWindow ? windowStartedAtMs : args.nowMs,
    windowCount: windowCount + 1,
    dayKey: args.dayKey,
    dayCount: dayCount + 1,
  };

  return {
    allowed: windowCount < args.windowLimit && dayCount < args.dailyLimit,
    next,
  };
}
