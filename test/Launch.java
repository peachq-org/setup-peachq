public class Launch {
    public static void main(String[] args) throws Exception {
        Process p = new ProcessBuilder(System.getenv("QCMD"), "smoke.q").inheritIO().start();
        System.exit(p.waitFor());
    }
}
