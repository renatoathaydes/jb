package m2;

import m1.M1;

public class M2 {
    final M1 m1;

    public M2( M1 m1 ) {
        this.m1 = m1;
    }

    public M1 getM1() {
        return m1;
    }

    public static void main( String[] args ) {
        M1 m1 = new M1( "This is M1" );

        var m2 = new M2( m1 );

        System.out.println( m2.getM1() );
    }
}