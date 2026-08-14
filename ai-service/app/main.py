"""
独立运行入口 —— 只是为了方便你自己本地测试(不依赖backend队友的项目)。

本地跑起来的方式:
    uvicorn app.main:app --reload --port 8000

跑起来之后打开 http://localhost:8000/docs 可以在网页上直接测试接口。

正式合并进backend队友的项目时,不用这个文件,他直接 import app/router.py
里的 router 对象挂到他自己的主app上就行(见 router.py 顶部注释)。
"""

from fastapi import FastAPI

from app.router import router

app = FastAPI(title="PaceHealth AI Service")
app.include_router(router)
