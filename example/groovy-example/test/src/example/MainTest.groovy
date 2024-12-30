package example

import spock.lang.Specification

@groovy.transform.Immutable
class Hi {
    String name
    boolean isTrue
}

class MainTest extends Specification {

    def 'hello spock'() {
        given: 'The Hello object'
        def hello = new Hello()
        
        when: 'say hello'
        hello.sayHello()

        then:
        noExceptionThrown()        
    }

    def 'Immutable test'() {
        given: 'An immutable Groovy object'
        def hi = new Hi(name: 'foo', isTrue: true)

        when: 'Try to modify it'
        hi.isTrue = false

        then: 'An error occurs'
        thrown Exception        
    }
    
}
