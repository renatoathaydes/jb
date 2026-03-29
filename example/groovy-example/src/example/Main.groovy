package example

/**
 * The hello class.
 */
class Hello {
    /**
     * Say hello.
     * @return null
     */
    def sayHello() {
        println 'Hello Groovy!'
    }
}

def hello = new Hello()
hello.sayHello()
