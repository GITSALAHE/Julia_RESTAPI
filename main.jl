import HttpCommon
import JSON
using HttpServer
using MySQL

type Post
    id::Int32
    title::String
    content::String
end

conn = mysql_connect("localhost", "root", "", "juliarestapi")

handler = HttpHandler() do req::Request, res::Response
    responseHeaders = HttpCommon.headers()
    responseHeaders["Access-Control-Allow-Origin"] = "*"
    responseHeaders["Content-Type"] = "application/json"
    responseStatus = 200
    if length(req.data) > 0
        requestData = JSON.parse(String(req.data))
    end

    if req.resource == "/posts"
        if req.method == "GET"
            posts = Post[]
            for row in MySQLRowIterator(conn, "SELECT * FROM posts")
                push!(posts, Post(row[1], row[2], row[3]))
            end
            responseData = posts
        end
        if req.method == "POST"
            mysql_execute(conn, "INSERT INTO posts (title, description) VALUES ('$(requestData["title"])', '$(requestData["description"])')")
            result = mysql_execute(conn, "SELECT * FROM posts WHERE id=$(mysql_insert_id(conn))", opformat=MYSQL_TUPLES)
            responseData = Post(result[1][1], result[1][2], result[1][3])
        end
    end

    if ismatch(r"^/posts/[0-9]{1,}$", req.resource)
        id = split(req.resource, '/')[3]
        if req.method == "GET"
            result = mysql_execute(conn, "SELECT * FROM posts WHERE id=$id", opformat=MYSQL_TUPLES)
            if length(result) == 1
                responseData = Post(result[1][1], result[1][2], result[1][3])
            else
                responseData = "Post not found"
                responseStatus = 404
            end
        end

        if req.method == "PUT"
            rowsAffected = mysql_execute(conn, "UPDATE posts SET title='$(requestData["title"])', description='$(requestData["description"])' WHERE id=$id")
            if rowsAffected == 1
                result = mysql_execute(conn, "SELECT * FROM posts WHERE id=$id", opformat=MYSQL_TUPLES)
                responseData = Post(result[1][1], result[1][2], result[1][3])
            else
                responseData = "Post not found"
                responseStatus = 404
            end
        end
        if req.method == "DELETE"
            rowsAffected = mysql_execute(conn, "DELETE FROM posts WHERE id=$id")
            if rowsAffected == 1
                posts = Post[]
                for row in MySQLRowIterator(conn, "SELECT * FROM posts")
                    push!(posts, Post(row[1], row[2], row[3]))
                end
                responseData = posts
            else
                responseData = "Post not found"
                responseStatus = 404
            end
        end
    end
    
    try
        responseData
    catch
        responseData = "Not found"
        responseStatus = 404
    end
    Response(responseStatus, responseHeaders, JSON.json(responseData))
end

run(Server(handler), 8000)