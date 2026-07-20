package app;

public final class MaintenanceAppTest {
    public static void main(String[] args) {
        String report = MaintenanceApp.report("test-run");

        assertContains(report, "workflow=build-maintenance");
        assertContains(report, "message=template=");
        assertContains(report, "audit=event=test-run");
    }

    private static void assertContains(String text, String expected) {
        if (!text.contains(expected)) {
            throw new AssertionError("expected output to contain '" + expected + "' but got:\n" + text);
        }
    }
}
