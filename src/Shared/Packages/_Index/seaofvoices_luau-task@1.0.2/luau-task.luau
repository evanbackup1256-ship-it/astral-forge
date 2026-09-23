export type TaskLibrary = {
    spawn: <T...>(fn: thread | (T...) -> ...any, T...) -> thread,
    defer: <T...>(fn: thread | (T...) -> ...any, T...) -> thread,
    delay: <T...>(duration: number, fn: thread | (T...) -> ...any, T...) -> thread,
    wait: (duration: number?) -> number,
    cancel: (thread) -> (),
}

return (task :: any) :: TaskLibrary
