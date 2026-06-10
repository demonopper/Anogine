# TempEngine

```
@if x > t then
hello
@if x < y then
world
@end

@else
bye bye world
@end


hello @name // name i buffera ekler

@for i=1,10 do
its @(i-1) th time // @(expr) syntax 
@end

@fun() // fonksiyonu çalıştırır değerini buffera ekler component olmaz yani

<@name width={20} height={100} style="" bold> </@> // sadece isim geçilenler otomatik name=true olarak geçer
veya
<@name /> 
bu sadece component alır yani fun(Component, attr)

@{
    local function loop()
        for i=1,10 do
            @{<li>its @i th time</li>}
        end
    end
}

@{loop() -- statement with side effects}
@(expr)
@identifierExpr
@funExpr() 
$(deferredExpr)
${deferredText mode}

<@slot/> // bu her zaman vardır layout felan yaparken unutmamak lazım


```