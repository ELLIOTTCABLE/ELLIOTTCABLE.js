###
These are my coedz. There are many like them, but these are mine ...
http://ell.io/twitter
###

module.exports =
ELLIOTTCABLE =
   
   _:_ = require 'lodash/dist/lodash.compat.min'
   
   # NYDocumented. >,>
   # (Honestly, I'm afraid to.)
   constructify: (opts) ->
      inner = (body) ->
         Wrapper = ->
            
            unless this instanceof Wrapper
               (F = -> @constructor = Wrapper; return this).prototype = Wrapper.prototype; it = new F
               return Wrapper.apply it, arguments
            
            # TODO: Functionality to control arguments passed to the superclass
            Wrapper.__super__?.constructor?.call this
            
            rv = body[ if opts.arguments == 'intact' then 'call' else 'apply' ] this, arguments
            rv = this if typeof rv != 'object' or opts.return
            
            return rv
         
         # Wow. Okay. So, CoffeeScript wraps *our* wrapper in another wrapper, that then calls us
         # (understandably). This means that our `Wrapper` is no longer the *actual type* we're
         # trying to construct (that is, the nominal “constructor function” whose prototype we're
         # trying to construct.)
         #
         # My approach to solving this is to replace *our wrapper*'s prototype with
         # CoffeeScript's-wrapper's prototype, the first time it *looks* like we're getting called
         # from a CoffeeScript wrapper.
         #
         # Unfortunately, my method for testing for “CoffeeScript-wrapper-ness” in the caller, is
         # rather fragile. I don't know how else to reliably go about this, right now.
         # 
         # This *SHOULD NOT* affect you if you're using this in the most common, intended fashion
         # (as a direct tag on a CoffeeScript class.)
         #
         # TODO: This is surely the most fragile thing ever conceived. Contact the Guinness.
         before_interceptor = ->
            cs_wrapper = before_interceptor.caller
            # The method we actually use to test “CoffeeScript-wrapper-ness”: first off, it calls
            # `#apply`, which we've here intercepted. Second, we know that the wrapper itself will
            # have a defined (and non-zero-length) function-name (which *no other function* in
            # CoffeeScript can have); third, we know that the second argument given to `#apply` will
            # be an `arguments` object, and thus have a `callee` property, referring to the
            # CoffeeScript wrapper itself, our caller.
            if cs_wrapper.name?.length > 0 and arguments[1].callee == cs_wrapper
               Wrapper.prototype = cs_wrapper.prototype
               Wrapper.__super__ = cs_wrapper.__super__ if cs_wrapper.__super__?
               Wrapper.apply = Function::apply
            else
               Wrapper.apply = after_interceptor
            return Function::apply.apply Wrapper, arguments
         after_interceptor = ->
            cs_wrapper = after_interceptor.caller
            if cs_wrapper.name?.length > 0 and arguments[1].callee == cs_wrapper
               console.error """
                  Oh-oh! It looks like a CoffeeScript constructor-wrapper has tried to call a
                         constructor that you've called `constructify()` on, *after* you've
                         otherwise called that function yourself. Due to the (unfortunately,
                         extremely fragile) approach that we take to handle CoffeeScript's
                         unfortunate indirection, you'll have to refactor your code so that
                         CoffeeScript's constructor is *always* called first. \n"""
               throw new ReferenceError "CoffeeScript wrapper called after other constructor invocations"
            return Function::apply.apply Wrapper, arguments
         
         Wrapper.apply = before_interceptor
         return Wrapper
      
      return inner(opts) if typeof opts == 'function'
      return inner
   
   
   # This is a “tag” that's intended to be inserted before CoffeeScript class-definitions:
   # 
   #     parameterizable class Something
   #        constructor: ->
   #           # ...
   #           return this
   # 
   # When tagged thus, the class will provide `Klass.with()(...)` and `instance.with()...` methods.
   # These will store any argument given, temporarily, on `this._`. The intended use thereof is for
   # further parameterizing methods which need complex or variable numbers of arguments in their
   # *actual invocation*, thus leaving no room for the quintessential (and indespensible) “options”
   # argument. An example:
   #
   #     new Arrayish.with(makeAwesome: no)(element, element2, element3 ...)
   # 
   # There are two extremely important caveats to its use:
   #
   #  - First off, CoffeeScript *does not* generate constructors that explicitly return the
   #    constructed value; it's assumed (reasonably enough) that the constructor will always be
   #    called via the `new` invocaton pattern, which ensures such a return. When using a
   #    “parameterized call pattern” as per this function's intended use, the final constructor
   #    itself is *not* called via a `new` invocation pattern (even though such is simulated
   #    reasonably well.)
   #
   #    **tl;dr**: Your constructors *must* explicitly `return this`.
   # 
   #  - Second, because I don't wish to leave extra cruft on the instances of `parameterizable`
   #    ‘classes,’ this implementation automatically deletes the options member at the *end of the
   #    reactor-tick wherein it was defined*. This means both that you must immediately call any
   #    parameterized constructor, and, more importantly, that the options member *will not be
   #    available* within asynchronous calls.
   #    
   #    As an example, the following will not work:
   #
   #        parameterizable class Something
   #           constructor: ->
   #              asynchronousOperation (result) ->
   #                 if (@_.beAwesome) ...
   #    
   #    The idiomatic way around this, is to store the options object to a local variable if you
   #    will be needing it across multiple reactor ticks. This, in my experience, is an edge-case.
   # ----
   # TODO: This could all be a lot more succinct, and prettier.
   parameterizable: (Klass) ->
      Klass.with = (opts) ->
         
         # XXX: Perhaps this should use constructify()?
         # XXX: Should this handle super-constructors?
         F = -> @constructor = Klass; return this
         F:: = Klass::
         it = new F
         
         it.with opts
         bound = _.bind Klass, it
         _.assign bound, Klass
         bound.prototype = Klass.prototype
         bound._ = opts
         process.nextTick => delete bound._
         bound
         
      Klass.prototype.with = (@_) ->
         process.nextTick => delete @_
         return this
      
      return Klass
   
   # Another “tag” for CoffeeScript classes, to cause them to delegate any undefined methods to
   # another class, if they *are* defined on that other class.
   delegated: (member, delegatee) -> (klass) ->
      functions = _(delegatee::).functions().map (f) ->
         mapped = -> delegatee::[f].apply this[member], arguments
         [f, mapped]
      _.defaults klass::, functions.object().valueOf()
      
      return klass
   
   infect: (globals, wif = utilities) -> _.assign globals, wif
