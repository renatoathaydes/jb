package jb.api;

import java.io.IOException;
import java.util.Set;

/**
 * A jb build task.
 */
public interface JbTask {

    /**
     * @return task name
     */
    String getName();

    /**
     * @return task description
     */
    String getDescription();

    /**
     * Get the task phase.
     * <p>
     * Built-in phases are {@code setup}, {@code build} and {@code tearDown}.
     *
     * @return task phase
     */
    default TaskPhase getPhase() {
        return TaskPhase.BUILD;
    }

    /**
     * Get the task inputs.
     * <p>
     * Inputs may be file entities paths or simple patterns. Paths ending with a {@code /} are directories.
     * Patterns may be of the simple form {@code *.txt} to match files by extension on a
     * particular directory, or {@code **&#47;some-dir/*.txt} to also include files in subdirectories.
     *
     * @return input paths and patterns
     */
    Set<String> getInputs();

    /**
     * Get the task outputs.
     * <p>
     * Outputs may be file entities paths or simple patterns. Paths ending with a {@code /} are directories.
     * Patterns may be of the simple form {@code *.txt} to match files by extension on a
     * particular directory, or {@code **&#47;some-dir/*.txt} to also include files in subdirectories.
     *
     * @return output paths and patterns
     */
    Set<String> getOutputs();

    /**
     * Run this task.
     * <p>
     * To signal an error without causing jb to print the full stack-trace, throw either {@link IOException}
     * or {@link JbException}. Any other {@link Throwable} is considered a programmer error and will result in the
     * stack-trace being printed.
     *
     * @param args    command-line arguments provided by the user
     * @param context the task context
     * @throws IOException if an IO errors occur
     */
    void run( String[] args, TaskContext context ) throws IOException;
}
