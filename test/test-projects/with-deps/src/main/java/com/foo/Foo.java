package com.foo;

import lists.*;
import minimal.sample.Sample;

public class Foo {
    public static void main( String[] args ) {
        System.out.println(Sample.message() + ListFactory.listOf(1, 2, 3));
    }
}
