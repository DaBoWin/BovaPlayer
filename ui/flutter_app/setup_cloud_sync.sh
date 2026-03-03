#!/bin/bash

# BovaPlayer 云同步功能设置脚本
# 用途：自动完成依赖安装和基础配置

set -e  # 遇到错误立即退出

echo "================================"
echo "BovaPlayer 云同步功能设置"
echo "================================"
echo ""

# 检查是否在正确的目录
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 错误：请在 ui/flutter_app 目录下运行此脚本"
    exit 1
fi

# 检查 .env 文件
if [ ! -f ".env" ]; then
    echo "❌ 错误：.env 文件不存在"
    echo "请先配置 .env 文件"
    exit 1
fi

echo "✅ 找到 .env 文件"
echo ""

# Step 1: 安装依赖
echo "📦 Step 1: 安装 Flutter 依赖..."
flutter pub get

if [ $? -eq 0 ]; then
    echo "✅ 依赖安装成功"
else
    echo "❌ 依赖安装失败"
    exit 1
fi

echo ""

# Step 2: 清理构建缓存
echo "🧹 Step 2: 清理构建缓存..."
flutter clean

echo "✅ 缓存清理完成"
echo ""

# Step 3: 生成代码（如果需要）
echo "🔧 Step 3: 检查代码生成..."
if [ -f "build_runner.yaml" ]; then
    echo "运行 build_runner..."
    flutter pub run build_runner build --delete-conflicting-outputs
    echo "✅ 代码生成完成"
else
    echo "⏭️  跳过代码生成（不需要）"
fi

echo ""

# Step 4: 验证配置
echo "🔍 Step 4: 验证配置..."

# 检查 Supabase URL
if grep -q "SUPABASE_URL=https://coljzupoztgupdmadmnr.supabase.co" .env; then
    echo "✅ Supabase URL 配置正确"
else
    echo "⚠️  警告：Supabase URL 可能未正确配置"
fi

# 检查 Anon Key
if grep -q "SUPABASE_ANON_KEY=eyJ" .env; then
    echo "✅ Supabase Anon Key 已配置"
else
    echo "❌ 错误：Supabase Anon Key 未配置"
    exit 1
fi

echo ""

# 完成
echo "================================"
echo "✅ 设置完成！"
echo "================================"
echo ""
echo "📋 下一步操作："
echo ""
echo "1. 执行数据库脚本："
echo "   - 打开 Supabase Dashboard"
echo "   - 进入 SQL Editor"
echo "   - 复制并执行 .kiro/specs/cloud-sync/database/01_create_tables.sql"
echo ""
echo "2. 配置认证："
echo "   - 在 Supabase Dashboard 启用 Email 认证"
echo "   - （可选）配置 GitHub OAuth"
echo ""
echo "3. 运行应用："
echo "   flutter run"
echo ""
echo "详细说明请查看: SUPABASE_SETUP_GUIDE.md"
echo ""
