package logging;

public final class AuditLog {
    private AuditLog() {}

    public static String entry(String event) {
        return "audit=event=" + event;
    }
}
