package com.htmake.reader.api.controller

import io.legado.app.data.entities.Book
import io.legado.app.data.entities.BookChapter
import io.legado.app.data.entities.SearchBook
import io.legado.app.data.entities.BookGroup
import io.legado.app.data.entities.BookSource
import io.legado.app.data.entities.RssSource
import io.legado.app.data.entities.RssArticle
import io.legado.app.model.webBook.WebBook
import io.vertx.ext.web.Route
import io.vertx.ext.web.Router
import io.vertx.ext.web.RoutingContext
import io.vertx.ext.web.handler.StaticHandler;
import mu.KotlinLogging
import com.htmake.reader.config.AppConfig
import com.htmake.reader.config.BookConfig
import io.legado.app.constant.DeepinkBookSource
import com.htmake.reader.utils.error
import com.htmake.reader.utils.success
import com.htmake.reader.utils.getStorage
import com.htmake.reader.utils.saveStorage
import com.htmake.reader.utils.asJsonArray
import com.htmake.reader.utils.asJsonObject
import com.htmake.reader.utils.toDataClass
import com.htmake.reader.utils.toMap
import com.htmake.reader.utils.fillData
import com.htmake.reader.utils.getWorkDir
import com.htmake.reader.utils.getRandomString
import com.htmake.reader.utils.genEncryptedPassword
import com.htmake.reader.entity.User
import com.htmake.reader.utils.SpringContextUtils
import com.htmake.reader.utils.deleteRecursively
import com.htmake.reader.utils.unzip
import com.htmake.reader.utils.zip
import com.htmake.reader.utils.jsonEncode
import com.htmake.reader.utils.getRelativePath
import com.htmake.reader.verticle.RestVerticle
import com.htmake.reader.SpringEvent
import org.springframework.stereotype.Component
import io.vertx.core.json.JsonObject
import io.vertx.core.json.JsonArray
import io.vertx.core.http.HttpMethod
import com.htmake.reader.api.ReturnData
import io.legado.app.utils.MD5Utils
import java.net.URLDecoder;
import java.net.URI
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.SocketTimeoutException
import java.nio.charset.StandardCharsets
import java.io.ByteArrayOutputStream
import java.net.URLEncoder;
import java.net.URL;
import java.util.UUID;
import io.vertx.ext.web.client.WebClient
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.core.env.Environment
import java.io.File
import java.lang.Runtime
import kotlin.collections.mutableMapOf
import kotlin.system.measureTimeMillis
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat;
import io.legado.app.utils.EncoderUtils
import io.legado.app.model.rss.Rss
import org.springframework.scheduling.annotation.Scheduled
import io.legado.app.model.localBook.LocalBook
import java.nio.file.Paths
import kotlinx.coroutines.withContext
import kotlinx.coroutines.async
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.CoroutineScope

private val logger = KotlinLogging.logger {}

class BookSourceController(coroutineContext: CoroutineContext): BaseController(coroutineContext) {
    private var webClient: WebClient

    init {
        webClient = SpringContextUtils.getBean("webClient", WebClient::class.java)
    }

    suspend fun getUserBookSourceJson(userNameSpace: String): JsonArray? {
        var bookSourceList: JsonArray? = asJsonArray(getUserStorage(userNameSpace, "bookSource"))
        if (bookSourceList == null && !userNameSpace.equals("default")) {
            // 用户书源文件不存在，拷贝系统书源
            var systemBookSourceList: JsonArray? = asJsonArray(getUserStorage("default", "bookSource"))
            if (systemBookSourceList != null) {
                saveUserStorage(userNameSpace, "bookSource", systemBookSourceList.getList())
                bookSourceList = systemBookSourceList
            }
        }
        return bookSourceList
    }

    suspend fun saveBookSource(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        val bookSource = BookSource.fromJson(context.bodyAsString).getOrNull()
        if (bookSource == null) {
            return returnData.setErrorMsg("参数错误")
        }
        // val bookSource = context.bodyAsJson.mapTo(BookSource::class.java)

        var userNameSpace = getUserNameSpace(context)
        var bookSourceList = getUserBookSourceJson(userNameSpace)
        if (bookSourceList == null) {
            bookSourceList = JsonArray()
        }
        // 遍历判断书本是否存在
        var existIndex: Int = -1
        for (i in 0 until bookSourceList.size()) {
            var _bookSource = bookSourceList.getJsonObject(i).mapTo(BookSource::class.java)
            if (_bookSource.bookSourceUrl.equals(bookSource.bookSourceUrl)) {
                existIndex = i
                break;
            }
        }
        if (existIndex >= 0) {
            var sourceList = bookSourceList.getList()
            sourceList.set(existIndex, JsonObject.mapFrom(bookSource))
            bookSourceList = JsonArray(sourceList)
        } else {
            bookSourceList.add(JsonObject.mapFrom(bookSource))
        }

        // logger.info("bookSourceList: {}", bookSourceList)
        saveUserStorage(userNameSpace, "bookSource", bookSourceList)
        return returnData.setData("")
    }

    suspend fun saveBookSources(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        val bookSourceJsonArray = context.bodyAsJsonArray
        if (bookSourceJsonArray == null) {
            return returnData.setErrorMsg("参数错误")
        }
        var userNameSpace = getUserNameSpace(context)
        var bookSourceList = getUserBookSourceJson(userNameSpace)
        if (bookSourceList == null) {
            bookSourceList = JsonArray()
        }
        for (k in 0 until bookSourceJsonArray.size()) {
            val bookSource = BookSource.fromJson(bookSourceJsonArray.getJsonObject(k).toString()).getOrNull()
            if (bookSource == null) {
                continue
            }
            // var bookSource = bookSourceJsonArray.getJsonObject(k).mapTo(BookSource::class.java)
            // 遍历判断书本是否存在
            var existIndex: Int = -1
            for (i in 0 until bookSourceList!!.size()) {
                var _bookSource = bookSourceList.getJsonObject(i).mapTo(BookSource::class.java)
                if (_bookSource.bookSourceUrl.equals(bookSource.bookSourceUrl)) {
                    existIndex = i
                    break;
                }
            }
            if (existIndex >= 0) {
                var sourceList = bookSourceList.getList()
                sourceList.set(existIndex, JsonObject.mapFrom(bookSource))
                bookSourceList = JsonArray(sourceList)
            } else {
                bookSourceList.add(JsonObject.mapFrom(bookSource))
            }
        }

        // logger.info("bookSourceList: {}", bookSourceList)
        saveUserStorage(userNameSpace, "bookSource", bookSourceList!!)
        return returnData.setData("")
    }

    suspend fun getBookSource(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        checkAuth(context)
        var bookSourceUrl: String
        if (context.request().method() == HttpMethod.POST) {
            // post 请求
            bookSourceUrl = context.bodyAsJson.getString("bookSourceUrl")
        } else {
            // get 请求
            bookSourceUrl = context.queryParam("bookSourceUrl").firstOrNull() ?: ""
        }
        if (bookSourceUrl.isNullOrEmpty()) {
            return returnData.setErrorMsg("书源链接不能为空")
        }

        var userNameSpace = getUserNameSpace(context)
        var bookSourceList = getUserBookSourceJson(userNameSpace)
        if (bookSourceList == null) {
            bookSourceList = JsonArray()
        }
        // 遍历判断书本是否存在
        var existIndex: Int = -1
        for (i in 0 until bookSourceList.size()) {
            var _bookSource = bookSourceList.getJsonObject(i).mapTo(BookSource::class.java)
            if (_bookSource.bookSourceUrl.equals(bookSourceUrl)) {
                existIndex = i
                break;
            }
        }
        if (existIndex < 0) {
            return returnData.setErrorMsg("书源信息不存在")
        }

        return returnData.setData(bookSourceList.getJsonObject(existIndex).map)
    }

    suspend fun getBookSources(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        checkAuth(context)
        var simple: Int = 0
        if (context.request().method() == HttpMethod.POST) {
            // post 请求
            simple = context.bodyAsJson.getInteger("simple", 0)
        } else {
            // get 请求
            simple = context.queryParam("simple").firstOrNull()?.toInt() ?: 0
        }
        var userNameSpace = getUserNameSpace(context)
        var bookSourceList = getUserBookSourceJson(userNameSpace)
        if (bookSourceList != null) {
            if (simple > 0) {
                var list = arrayListOf<Map<String, Any?>>()
                for (i in 0 until bookSourceList.size()) {
                    var bookSource = bookSourceList.getJsonObject(i).mapTo(BookSource::class.java)
                    list.add(mapOf<String, Any?>(
                        "bookSourceGroup" to bookSource.bookSourceGroup,
                        "bookSourceName" to bookSource.bookSourceName,
                        "bookSourceUrl" to bookSource.bookSourceUrl,
                        "exploreUrl" to bookSource.exploreUrl
                    ))
                }
                return returnData.setData(list)
            }
            return returnData.setData(bookSourceList.getList())
        }
        return returnData.setData(arrayListOf<Int>())
    }

    suspend fun deleteBookSource(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        val bookSource = context.bodyAsJson.mapTo(BookSource::class.java)

        var userNameSpace = getUserNameSpace(context)
        var bookSourceList = getUserBookSourceJson(userNameSpace)
        if (bookSourceList == null) {
            bookSourceList = JsonArray()
        }
        // 遍历判断书本是否存在
        var existIndex: Int = -1
        for (i in 0 until bookSourceList.size()) {
            var _bookSource = bookSourceList.getJsonObject(i).mapTo(BookSource::class.java)
            if (_bookSource.bookSourceUrl.equals(bookSource.bookSourceUrl)) {
                existIndex = i
                break;
            }
        }
        if (existIndex >= 0) {
            bookSourceList.remove(existIndex)
        }

        // logger.info("bookSourceList: {}", bookSourceList)
        saveUserStorage(userNameSpace, "bookSource", bookSourceList)
        return returnData.setData("")
    }

    suspend fun deleteBookSources(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        val bookSourceJsonArray = context.bodyAsJsonArray

        var userNameSpace = getUserNameSpace(context)
        var bookSourceList = getUserBookSourceJson(userNameSpace)
        if (bookSourceList == null) {
            bookSourceList = JsonArray()
        }
        for (k in 0 until bookSourceJsonArray.size()) {
            var bookSource = bookSourceJsonArray.getJsonObject(k).mapTo(BookSource::class.java)
            // 遍历判断书本是否存在
            var existIndex: Int = -1
            for (i in 0 until bookSourceList.size()) {
                var _bookSource = bookSourceList.getJsonObject(i).mapTo(BookSource::class.java)
                if (_bookSource.bookSourceUrl.equals(bookSource.bookSourceUrl)) {
                    existIndex = i
                    break;
                }
            }
            if (existIndex >= 0) {
                bookSourceList.remove(existIndex)
            }
        }

        // logger.info("bookSourceList: {}", bookSourceList)
        saveUserStorage(userNameSpace, "bookSource", bookSourceList)
        return returnData.setData("")
    }

    suspend fun deleteAllBookSources(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        var userNameSpace = getUserNameSpace(context)
        saveUserStorage(userNameSpace, "bookSource", JsonArray())
        return returnData.setData("")
    }

    suspend fun setAsDefaultBookSources(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        if (!checkManagerAuth(context)) {
            return returnData.setData("NEED_SECURE_KEY").setErrorMsg("请输入管理密码")
        }
        var username = context.bodyAsJson.getString("username")
        var bookSourceList: JsonArray? = asJsonArray(getUserStorage(username, "bookSource"))
        if (bookSourceList == null) {
            return returnData.setErrorMsg("用户书源不存在")
        }

        // 保存为默认书源
        saveUserStorage("default", "bookSource", bookSourceList.getList())
        return returnData.setData("设置默认书源成功")
    }

    suspend fun readSourceFile(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (context.fileUploads() == null || context.fileUploads().isEmpty()) {
            return returnData.setErrorMsg("请上传文件")
        }
        var sourceList = JsonArray()
        context.fileUploads().forEach {
            // logger.info("readSourceFile: {}", it.uploadedFileName())
            var file = File(it.uploadedFileName())
            if (file.exists()) {
                sourceList.add(file.readText())
                file.delete()
            }
        }
        return returnData.setData(sourceList.getList())
    }

    private companion object {
        const val MAX_REMOTE_SOURCE_BYTES = 5 * 1024 * 1024
        const val MAX_REMOTE_REDIRECTS = 5
        const val REMOTE_TIMEOUT_MS = 10_000
    }

    private fun validateRemoteUri(value: String): URI {
        val uri = try { URI(value.trim()) } catch (e: Exception) {
            throw IllegalArgumentException("远程 URL 格式不正确")
        }
        val scheme = uri.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") throw IllegalArgumentException("因安全策略拒绝：只允许 HTTP 或 HTTPS")
        if (!uri.userInfo.isNullOrEmpty() || uri.host.isNullOrEmpty()) throw IllegalArgumentException("因安全策略拒绝：URL 不得包含用户信息")
        val addresses = try { InetAddress.getAllByName(uri.host) } catch (e: Exception) {
            throw IllegalArgumentException("远程服务器无法解析")
        }
        if (addresses.isEmpty() || addresses.any { it.isAnyLocalAddress || it.isLoopbackAddress || it.isLinkLocalAddress || it.isSiteLocalAddress || it.hostAddress.startsWith("169.254.") || it.hostAddress.startsWith("100.64.") }) {
            throw IllegalArgumentException("因安全策略拒绝：目标地址属于本机、内网或容器网络")
        }
        if (addresses.any { it.hostAddress == "169.254.169.254" || it.hostAddress == "100.100.100.200" }) throw IllegalArgumentException("因安全策略拒绝：禁止访问云 metadata 地址")
        return uri
    }

    private fun readRemoteJson(url: String): String {
        var current = validateRemoteUri(url)
        repeat(MAX_REMOTE_REDIRECTS + 1) { redirectCount ->
            val connection = current.toURL().openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = REMOTE_TIMEOUT_MS
            connection.readTimeout = REMOTE_TIMEOUT_MS
            connection.setRequestProperty("Accept", "application/json, text/plain;q=0.8, */*;q=0.1")
            connection.setRequestProperty("User-Agent", "reader-web-source-import")
            try {
                val status = connection.responseCode
                if (status in 300..399) {
                    if (redirectCount == MAX_REMOTE_REDIRECTS) throw IllegalArgumentException("远程服务器重定向次数过多")
                    val location = connection.getHeaderField("Location") ?: throw IllegalArgumentException("远程服务器重定向地址为空")
                    current = validateRemoteUri(current.resolve(location).toString())
                    return@repeat
                }
                if (status !in 200..299) throw IllegalArgumentException("远程服务器返回 HTTP $status")
                val contentLength = connection.getHeaderFieldLong("Content-Length", -1L)
                if (contentLength > MAX_REMOTE_SOURCE_BYTES) throw IllegalArgumentException("远程响应过大，限制为 5 MB")
                val output = ByteArrayOutputStream()
                connection.inputStream.use { input ->
                    val buffer = ByteArray(8192)
                    var total = 0
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > MAX_REMOTE_SOURCE_BYTES) throw IllegalArgumentException("远程响应过大，限制为 5 MB")
                        output.write(buffer, 0, count)
                    }
                }
                val body = String(output.toByteArray(), StandardCharsets.UTF_8).removePrefix("\uFEFF").trim()
                try { io.vertx.core.json.JsonArray(body) } catch (_: Exception) {
                    try { io.vertx.core.json.JsonObject(body) } catch (_: Exception) { throw IllegalArgumentException("返回内容不是可识别书源 JSON") }
                }
                return body
            } finally { connection.disconnect() }
        }
        throw IllegalArgumentException("远程书源读取失败")
    }

    suspend fun readRemoteSourceFile(context: RoutingContext) {
        val returnData = ReturnData()
        if (!checkAuth(context)) { context.success(returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")); return }
        val url = if (context.request().method() == HttpMethod.POST) context.bodyAsJson.getString("url") ?: "" else context.queryParam("url").firstOrNull() ?: ""
        if (url.isBlank()) { context.success(returnData.setErrorMsg("请输入远程书源链接")); return }
        try {
            val body = withContext(Dispatchers.IO) { readRemoteJson(url) }
            context.success(returnData.setData(arrayListOf(body)))
        } catch (e: SocketTimeoutException) {
            context.success(returnData.setErrorMsg("请求远程书源超时"))
        } catch (e: IllegalArgumentException) {
            context.success(returnData.setErrorMsg(e.message ?: "远程书源读取失败"))
        } catch (e: Exception) {
            logger.warn("remote source import failed: {}", e.message)
            context.success(returnData.setErrorMsg("远程 URL 无法访问"))
        }
    }
    suspend fun deleteUserBookSource(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        if (!checkManagerAuth(context)) {
            return returnData.setData("NEED_SECURE_KEY").setErrorMsg("请输入管理密码")
        }
        val userJsonArray = context.bodyAsJsonArray
        for (i in 0 until userJsonArray.size()) {
            var username = userJsonArray.getString(i)
            var userBookSourceFile = File(getWorkDir("storage", "data", username, "bookSource.json"))
            // 删除用户书源文件，恢复默认书源
            if (userBookSourceFile.exists()) {
                userBookSourceFile.deleteRecursively()
            }
        }
        return returnData.setData("删除书源成功")
    }

    suspend fun deleteBookSourcesFile(context: RoutingContext): ReturnData {
        val returnData = ReturnData()
        if (!checkAuth(context)) {
            return returnData.setData("NEED_LOGIN").setErrorMsg("请登录后使用")
        }
        var userNameSpace = getUserNameSpace(context)
        var userBookSourceFile = File(getWorkDir("storage", "data", userNameSpace, "bookSource.json"))
        // 删除用户书源文件，恢复默认书源
        if (userBookSourceFile.exists()) {
            userBookSourceFile.deleteRecursively()
        }
        return returnData.setData("")
    }
}
