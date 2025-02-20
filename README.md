这里备份了一些我自己的rime配置和lua，目前是基于白霜方案。
需要的人可以拿去用或自行修改。

lua文件来自 https://github.com/hchunhui/librime-cloud 和 https://github.com/wzv5/rime-lua-script ，然后做了些修改。完成了以下功能：
1. 输入时按 0 进入单字模式
2. 输入时按 ctrl+T 进入云输入，上屏后自动记录到用户词库（含英文，英文记录在en_dicts/user_en.txt）
3. 输入英文后按shift+Enter可以把单词记录到用户词库，位置同上。
4. ctrl+符号可以在中文模式下直接输入英文符号，另外如果候选项第一项是英文，直接按符号可以上屏该选项和英文符号
