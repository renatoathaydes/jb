import jbuild.api.*;
import jbuild.api.change.ChangeSet;

import java.io.File;
import java.io.IOException;
import java.nio.file.CopyOption;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;
import static jbuild.api.JBuildException.ErrorCause.ACTION_ERROR;

@JbTaskInfo( name = "copyFile",
        description = "Copies files",
        phase = @TaskPhase( name = "setup" ) )
public final class CopierTask implements JbTask {
    private final JBuildLogger log;
    private final boolean overwrite;
    private final String[] extensions;

    public CopierTask( JBuildLogger log, String[] extensions ) {
        this( log, extensions, true );
    }

    public CopierTask( JBuildLogger log, String[] extensions, boolean overwrite ) {
        this.log = log;
        this.extensions = extensions;
        this.overwrite = overwrite;
    }

    @Override
    public List<String> inputs() {
        return Stream.of( extensions )
                .map( ext -> "input-resources/" + ext )
                .collect( Collectors.toList() );
    }

    @Override
    public List<String> outputs() {
        return Stream.of( extensions )
                .map( ext -> "output-resources/" + ext )
                .collect( Collectors.toList() );
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
        var inputs = getChangedAndDeleteRemovedFiles( changeSet );
        if ( inputs.length == 0 ) return;
        log.println( () -> "Copying " + inputs.length + " file(s) to output-resources directory" );
        var out = new File( "output-resources" );
        if ( !out.isDirectory() && !out.mkdirs() ) {
            throw new JBuildException( "Cannot create output directory " + out, ACTION_ERROR );
        }
        var copyOptions = overwrite
                ? new CopyOption[]{ REPLACE_EXISTING }
                : new CopyOption[ 0 ];
        for ( var input : inputs ) {
            Files.copy( input.toPath(), Paths.get( "output-resources", input.getName() ), copyOptions );
        }
    }

    private File[] getChangedAndDeleteRemovedFiles( ChangeSet changeSet ) {
        if ( changeSet == null || changeSet.getOutputChanges().iterator().hasNext() ) {
            log.verbosePrintln( "Performing full copy" );
            return new File( "input-resources" ).listFiles();
        }
        var changes = changeSet.getInputChanges();
        var result = new ArrayList<File>();
        changes.forEach( change -> {
            File file = new File( change.path );
            switch ( change.kind ) {
                case ADDED:
                case MODIFIED:
                    if ( !file.isFile() ) return; // only handle files, not dirs/links
                    result.add( file );
                    break;
                case DELETED:
                    if ( new File( "output-resources", file.getName() ).delete() ) {
                        log.println( "Deleted " + file.getName() );
                    }
            }
        } );
        return result.toArray( new File[ 0 ] );
    }

}
