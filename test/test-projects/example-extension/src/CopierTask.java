import jbuild.api.*;
import jbuild.api.change.ChangeSet;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;
import static jbuild.api.JBuildException.ErrorCause.ACTION_ERROR;

@JbTaskInfo( name = "copyFile",
        description = "Copies files",
        phase = @TaskPhase( name = "setup" ) )
public final class CopierTask implements JbTask {
    private final JBuildLogger log;

    public CopierTask( JBuildLogger log ) {
        this.log = log;
    }

    @Override
    public List<String> inputs() {
        return List.of( "input-resources/*" );
    }

    @Override
    public List<String> outputs() {
        return List.of( "output-resources/*" );
    }

    @Override
    public List<String> dependents() {
        return List.of( "compile" );
    }

    @Override
    public void run( String... args ) throws IOException {
        go( null );
    }

    @Override
    public void run( ChangeSet changeSet, String... args ) throws IOException {
        go( changeSet );
    }

    private void go( ChangeSet changeSet ) throws IOException {
        var inputs = getInputs( changeSet );
        if ( inputs == null ) throw new FileNotFoundException( "input-resources directory does not exist" );
        if ( inputs.length == 0 ) throw new JBuildException( "No input files found in input-resources directory",
                JBuildException.ErrorCause.USER_INPUT );
        log.println( () -> "Copying " + inputs.length + " file(s) to output-resources directory" );
        var out = new File( "output-resources" );
        if ( !out.isDirectory() && !out.mkdirs() ) {
            throw new JBuildException( "Cannot create output directory " + out, ACTION_ERROR );
        }
        for ( var input : inputs ) {
            Files.copy( input.toPath(), Paths.get( "output-resources", input.getName() ), REPLACE_EXISTING );
        }
    }

    private File[] getInputs( ChangeSet changeSet ) {
        if ( changeSet == null || changeSet.getOutputChanges().iterator().hasNext() ) {
            log.verbosePrintln( "Performing full copy" );
            return new File( "input-resources" ).listFiles();
        }
        var changes = changeSet.getInputChanges();
        var result = new ArrayList<File>();
        changes.forEach( c -> result.add( new File( c.path ) ) );
        log.verbosePrintln( () -> "Incrementally copying: " + result );
        return result.toArray( new File[ 0 ] );
    }

}
