# Anogine
Anogine is a transpiled (to lua) text engine that generates text from functions inside functions with feautes like
* full code mod for detailed usecases
    * fully recursive code mod to text mode switcher
* control flow
    * for, while loops
    * if else chain
* expression in text mode
* deferred patching
    * deferred text mode
    * deferred expr mode
* component syntax

## Context Switching
this is mostly nor required but it helps to think more in code first type and define variables and functions
```
@{
    local defaultAvatar = get_cdn_url("default.png")
    function formatDate(ts) return os.date("%Y-%m-%d", ts) end
    
    function generateCommentTree(comments)
        @{
            <ul class="comment-list">
            @{
            local datas = comments
            for i=1,#datas do 
                local comment = datas[i]
                @{
                <li class="comment-item">
                    <img src="@(comment.avatar or defaultAvatar)" />
                    <strong>@comment.author</strong> - @formatDate(comment.timestamp)
                    <p>@comment.text</p>
                    @{
                        if comment.replies then
                            generateCommentTree(comment.replies)
                        end
                    }
                </li>
                }
            end
            }
            </ul>
        }
    end
}

<section class="comments-section">
    <h3>User Comments</h3>
    @{generateCommentTree(attr.comments)} 
</section>
```
we wrap in code mode and not expr mode because generate graph doesnt give a value it side effects into writing in buffer

## Control Flow
Anogine has generic control flow sugars to prevent switching to code mode and text mode again for simple things
without sugars
```
<div class="pagination">
@{
    if attr.next_page_url then
        @{
            <a href="@attr.next_page_url" class="btn">Next Page &raquo;</a>
        }
    end
}
</div>
```
with sugars
```
<div class="pagination">
@if attr.next_page_url then
    <a href="@attr.next_page_url" class="btn">Next Page &raquo;</a>
@end
</div>
```
they handle %60-70 usecases pretty much

### If Else Chain
```
@if user.role == "admin" then
    <button class="bg-red">Delete Post</button>
@elseif user.role == "editor" then
    <button class="bg-blue">Edit Post</button>
@else
    <span class="text-gray">View Only Mode</span>
@end
```

### Loops
```
@for _, post in ipairs(ctx.recent_posts) do 
    <article>
        <h2>@post.title</h2>
        <p>@post.excerpt</p>
    </article>
@end

@while db_cursor:next() do
    <li>@db_cursor:get_value()</li>
@end
```

## expressions
in nature of variable text generations its not just static text injections so we gave a expr syntax with couple sugar
* identifier: `@user` or `@user.profile.avatar`
* fun: `@get_csrf_token()` or `@db.get_count()`
* generic: `@(item.price * item.quantity)` or `anything`

## Deferred Patching
Sometimes you need to output data at the top of your document (like processing times or stylesheet links) before the variables or asset graphs are actually finalized during the standard top-down render.

Anogine solves this via **Deferred Execution**, which marks tokens to be evaluated at the very end of the component's scope execution.
### Deferred Expressions
```
@{local starttime = os.clock()}
<p>rendering this component take $((os.clock() - starttime)*1000)ms</p>
```
its looks magic right :D 
### Deferred Text Mode
you might wanna turn a loop and generate more complex patch you dont need to write flat string array then `table.concat` you can still use text mode syntax
```
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    ${
        @for path, _ in pairs(ctx.styles) do
            <link rel="stylesheet" href=@string.format("%q", path)>
        @end
    }
    <title>$(ctx.title)</title>
</head>
<body>
    <@slot/>
</body>
</html>
```

## Component Syntax
what we want dry how we get components good components are functions but that syntax to write code is bad so what i did component syntax its basically a shortcut to write component(slot, attr, ctx) like html like syntax
```
<@SubmitButton primary size={60} class="btn-large">Publish Post</@>
```
its not 100% html or jsx but has fine boundaries other `<h1>` etc doesnt get executed handled like text like server side should do

but what about signature of component?
`---@alias Component fun(slot:Component, attr:table, ctx:table):nil`


### code ref
```
@if user.age >= 18 then
    Welcome to the adult section!
@elseif user.has_parental_consent then
    Welcome, supervised user!
@else
    Access denied.
@end

Hello @user.username @for _, item in ipairs(cart.items) do
    Item: @item.name (Total: @(item.price * item.quantity)) @end

@render_analytics_script() <@ProfileCard width={300} height={400} style="dark" verified> </@> <@Divider /> 
@{
    local function build_nav_menu()
        for _, link in ipairs(nav_links) do
            @{<li><a href="@link.url">@link.label</a></li>}
        end
    end
}

@{build_nav_menu() -- statement with side effects}
@(item.price * 1.20)
@user.profile.avatar
@format_date(post.created_at)
$(ctx.total_render_time)
${
    @for _, script in ipairs(ctx.deferred_scripts) do
        <script src="@script"></script>
    @end
}

<@slot/> 

```