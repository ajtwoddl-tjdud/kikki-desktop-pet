using System;
using System.Threading;

public static class KikkiUpdateSchedule {
    public static int FrameMilliseconds(bool visible, bool motion, bool active) {
        return !visible ? 0 : !motion ? 100 : active ? 33 : 67;
    }
}

// Wait on the existing named event without polling or running PowerShell on a worker thread.
public sealed class KikkiEventWatcher : IDisposable {
    private RegisteredWaitHandle registration;
    private readonly SynchronizationContext context;
    private readonly Action action;
    private int disposed;

    public KikkiEventWatcher(WaitHandle signal, SynchronizationContext context, Action action) {
        if (context == null) throw new ArgumentNullException("context");
        if (action == null) throw new ArgumentNullException("action");
        this.context = context;
        this.action = action;
        registration = ThreadPool.RegisterWaitForSingleObject(signal, OnSignal, null, Timeout.Infinite, false);
    }

    private void OnSignal(object state, bool timedOut) {
        if (Volatile.Read(ref disposed) != 0) return;
        context.Post(Deliver, null);
    }

    private void Deliver(object state) {
        if (Volatile.Read(ref disposed) == 0) action();
    }

    public void Dispose() {
        if (Interlocked.Exchange(ref disposed, 1) != 0) return;
        registration.Unregister(null);
    }
}
