package jb.api;

/**
 * A jb build phase.
 * <p>
 * All jb tasks are executed on a phase. A phase contains a group of tasks which may only run after tasks in the
 * previous phase have finished executing, regardless of task dependencies.
 */
public final class TaskPhase {

    public static final TaskPhase SETUP = new TaskPhase( "setup", 100 );
    public static final TaskPhase BUILD = new TaskPhase( "build", 500 );
    public static final TaskPhase TEAR_DOWN = new TaskPhase( "tearDown", 1000 );

    private final String name;

    private final int index;

    public TaskPhase( String name, int index ) {
        this.name = name;
        this.index = index;
    }

    /**
     * @return name of the phase
     */
    public String name() {
        return name;
    }

    /**
     * The index of the phase. Phases are ordered according to this index.
     *
     * @return index of the phase
     */
    public int index() {
        return index;
    }

}
