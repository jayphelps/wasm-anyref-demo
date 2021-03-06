(;
  My goal was to experiment and demonstrate how you could use JavaScript
  arrays as your Garbage Collected "struct" objects instead of shipping your own
  malloc and GC then dealing with JS <-> marshalling. Publishing in case others
  are interested in learning more about anyref and are looking for examples.

  It's implemented naively in many ways, so keep in mind this is only a proof of
  concept to help folks who already know some WebAssembly but want that "a ha"
  moment about how anyref by itself is still powerful.

  In practice this performs relatively poorly. Even if your Wasm
  runtime has optimized JS <-> Wasm bridge calls, using this technique would
  mean a lot of them. There's been talk about browser engines being able to
  maybe optimize imported Reflect.get() calls so they aren't actually function
  invocations and have little overhead, but AFAIK no movement yet.
 
  Even if those calls were optimized, some rudimentary testing suggests currently
  anyrefs in general are "slow" compared to equivalent JIT optimized JS.
  e.g. boxing alone appears slow. This might improve later as anyref is still
  early and experimental.

  Keep in mind that WebAssembly is planned to eventually have the ability to
  allocate GC-collected data structures without needing to import JS functions
  like we do here (the alloc_struct stuff) which would also improve perf.

  So in summary, this is slow now, but combined with a few other pending proposals
  (e.g. host bindings) you eventually won't need to ship a JS runtime. But that's
  a little ways in the future.

  ***

  The alloc_struct() functions are used to allocate a Garbage Collected data
  structure (aka struct, object, record, etc.) It's really more of a tuple since
  they don't have named fields at runtime, but I'm calling them structs to show
  that a hypothetical language could compile the field names away to just offsets,
  just like many languages do.

  You could invision this .wat file is the compiled output of some pseudo code
  from a hypothetical language that is garbage collected, like this:

  struct User {
    name: string,
    age: i32
  }

  struct Comment {
    user: User,
    content: string
  }

  fun main() {
    let name = 'Some Name'
    let age = 50
    let user = User { name, age }

    let content = 'Example comment text'
    let comment = Comment { user, content }

    log(comment)
    log(comment.content)
    log(comment.user.name)
  }
;)

(module
  (import "env" "memory" (memory $memory 1))
  (import "env" "anyref_table" (table $anyref_table 2 anyref))
  (;
    struct User {
      name: string, // offset: (i32.const 0)
      age: i32      // offset: (i32.const 1)
    }
  ;)
  (import "env" "alloc_struct2" (func $User (param anyref) (param i32) (result anyref)))
  (;
    struct Comment {
      user: User,      // offset: (i32.const 0)
      content: string  // offset: (i32.const 1)
    }
  ;)
  (import "env" "alloc_struct2" (func $Comment (param anyref) (param anyref) (result anyref)))
  (import "env" "get" (func $get (param anyref) (param i32) (result anyref)))
  (import "env" "log" (func $log (param anyref)))

  (func $main (export "main")
    (local $name anyref)
    (local $age i32)
    (local $user anyref)
    (local $content anyref)
    (local $comment anyref)

    (; === User creation ===
       ===================== ;)

    (; name is a GC reference string coming from the imported table ;)
    (set_local $name
      (table.get $anyref_table
        (i32.const 0)
      )
    )
    (; we use Wasm integers instead of JS numbers for ease/perf ;)
    (set_local $age
      (i32.const 50)
    )
    (; creating a garbage collected "tuple" struct ;)
    (set_local $user
      (call $User
        (get_local $name)
        (get_local $age)
      )
    )

    (; === Comment creation ===
       ======================== ;)

    (; name is a GC reference string coming from the imported table ;)
    (set_local $content
      (table.get $anyref_table
        (i32.const 1)
      )
    )

    (; GC record that contains even more GC records ;)
    (set_local $comment
      (call $Comment
        (get_local $user)
        (get_local $content)
      )
    )

    (; see how the entire data structure is stored ;)
    (; [['Some Name', 50], 'Example comment text'] ;)
    (call $log
      (get_local $comment)
    )

    (; === peek at individual fields ===
       ================================= ;)

    (; the comment's content ;)
    (; "Example comment text" ;)
    (call $log
      (call $get
        (get_local $comment)
        (i32.const 1)
      )
    )

    (; the comment's user's name ;)
    (; "Some name" ;)
    (call $log
      (call $get
        (call $get
          (get_local $comment)
          (; get the user ;)
          (i32.const 0)
        )
        (; get the user's name ;)
        (i32.const 0)
      )
    )
  )
)
