package app;

import logging.AuditLog;
import message.MessageTemplate;

public final class MaintenanceApp {
    private MaintenanceApp() {}

    public static void main(String[] args) {
        String event = args.length > 0 ? args[0] : "local-build";
        System.out.println(report(event));
    }

    static String report(String event) {
        return String.join(
                System.lineSeparator(),
                "workflow=build-maintenance",
                "message=" + MessageTemplate.render(),
                AuditLog.entry(event));
    }
}
