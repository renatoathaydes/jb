import jbuild.api.JbTask;
import jbuild.api.JbTaskInfo;

@JbTaskInfo( name = "sample-task",
        description = "A sample jb task.",
        inputs = { "*.txt" },
        outputs = { "*.out" } )
public final class SampleTask implements JbTask {
    @Override
    public void run( String... args ) {
        System.out.println( "Extension task running: " + getClass().getName() );
    }
}
