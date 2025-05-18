// serverless.js
const express = require('express');
const axios = require('axios');
const app = express();
app.use(express.json());

app.post('/run', async (req, res) => {
    try {
        // 打印收到的 /run 请求内容
        console.log('收到 /run 请求:', JSON.stringify(req.body));
        // 转发请求到 8082 的 /scrape_dengdai
        const response = await axios.post('http://localhost:8082/scrape_dengdai', req.body.input);
        // 打印 8082 的响应内容
        console.log('8082 响应:', JSON.stringify(response.data));
        // 返回 8082 的响应
        res.json({ output: response.data });
    } catch (err) {
        console.error('转发到 8082 出错:', err);
        res.status(500).json({ error: err.toString() });
    }
});

app.listen(5000, () => {
    console.log('Serverless API listening on port 5000');
});