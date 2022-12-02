package jb.api;

import java.io.File;
import java.util.Set;

/**
 * The context of a jb task.
 */
public interface TaskContext {
    /**
     * Get all the task inputs matching the paths and patterns declared in
     * {@link JbTask#getInputs()}.
     *
     * @return task inputs
     */
    Set<File> getAllInputs();

    /**
     * Get all the task outputs matching the paths and patterns declared in
     * {@link JbTask#getOutputs()}.
     *
     * @return task outputs
     */
    Set<File> getAllOutputs();

    /**
     * Get the sub-set of the task inputs that have been modified since last time this task has been executed.
     *
     * @return changed task inputs
     */
    Set<File> getChangedInputs();

    /**
     * Get the sub-set of the task outputs that have been modified since last time this task has been executed.
     *
     * @return changed task outputs
     */
    Set<File> getChangedOutputs();
}
