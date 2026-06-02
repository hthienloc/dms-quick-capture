#!/usr/bin/env python3
import os
import re
import shutil
import sys
from pathlib import Path

# Thư mục chứa dms-common gốc (nơi chứa script này)
DMS_COMMON_REPO = Path(__file__).parent.resolve()

def get_available_components():
    """Lấy danh sách các component có sẵn trong dms-common gốc."""
    components = {}
    for f in DMS_COMMON_REPO.glob("*.qml"):
        components[f.stem] = f
    return components

def get_dependencies_in_file(filepath, available_names):
    """Quét một file để tìm xem nó có dùng component nào trong danh sách không."""
    try:
        content = filepath.read_text(encoding="utf-8")
    except Exception:
        return set()
    
    deps = set()
    for name in available_names:
        # Tìm component name (có thể là tag <Name> hoặc Name { hoặc kiểu Name)
        pattern = r'\b' + name + r'\b'
        if re.search(pattern, content):
            deps.add(name)
    return deps

def main():
    target_dir = Path(os.getcwd())
    
    if target_dir == DMS_COMMON_REPO:
        print("Vui lòng chạy script này từ thư mục của plugin cần sync (vd: cd ../dms-timer && python3 ../dms-common/sync_common.py)")
        sys.exit(1)

    available_components = get_available_components()
    available_names = set(available_components.keys())
    
    # 1. Tìm các file QML trong plugin (loại trừ thư mục dms-common đích)
    plugin_qml_files = []
    for root, dirs, files in os.walk(target_dir):
        if "dms-common" in dirs:
            dirs.remove("dms-common")  # Không quét dms-common đích
        for file in files:
            if file.endswith(".qml"):
                plugin_qml_files.append(Path(root) / file)
                
    # 2. Thu thập components được dùng trong plugin
    used_components = set()
    for qml_file in plugin_qml_files:
        used_components.update(get_dependencies_in_file(qml_file, available_names))
        
    # 3. Phân tích dependency vòng (component trong dms-common gọi component khác)
    added_new = True
    while added_new:
        added_new = False
        current_used = list(used_components)
        for comp in current_used:
            comp_file = available_components[comp]
            deps = get_dependencies_in_file(comp_file, available_names)
            for d in deps:
                if d not in used_components:
                    used_components.add(d)
                    added_new = True

    if not used_components:
        print("Không tìm thấy component nào thuộc dms-common được sử dụng trong plugin này.")
        sys.exit(0)
        
    print(f"Các components cần thiết: {', '.join(sorted(used_components))}")
    
    # 4. Copy các components và tạo qmldir
    target_common = target_dir / "dms-common"
    if target_common.exists():
        shutil.rmtree(target_common)
    target_common.mkdir(parents=True)
    
    qmldir_lines = ["module dms.common"]
    for comp in sorted(used_components):
        src_file = available_components[comp]
        dst_file = target_common / src_file.name
        shutil.copy2(src_file, dst_file)
        qmldir_lines.append(f"{comp} 1.0 {src_file.name}")
        
    # Xử lý thư mục assets (copy toàn bộ nếu có)
    src_assets = DMS_COMMON_REPO / "assets"
    if src_assets.exists() and src_assets.is_dir():
        dst_assets = target_common / "assets"
        shutil.copytree(src_assets, dst_assets)
        
    # Ghi qmldir
    qmldir_path = target_common / "qmldir"
    qmldir_path.write_text("\n".join(qmldir_lines) + "\n", encoding="utf-8")
    
    print(f"Đã sync thành công {len(used_components)} components vào {target_common.relative_to(target_dir)}/.")

if __name__ == "__main__":
    main()
