import java.util.Set;
import jb.api.JbTask;
import jb.api.TaskContext;

public final class TestExtension implements JbTask {

    @Override
    public String getName() {
      return "example";
    }
    
    @Override
    public String getDescription() {
      return "Task description.";
    }

    @Override
    public Set<String> getInputs() {
      return Set.of("*.txt");
    }
    
    @Override
    public Set<String> getOutputs() {
      return Set.of("*.out");
    }
    
    @Override
    public void run(String[] args) {
        System.out.println("Extension task running: " + getClass().getName());
    }
}
