from moovparser.moovparser import Node, parse_nodes



file_path = r"C:\Users\lin\Videos\Captures\梦幻西游：129五开带魔花果山的另类组合，效率逆天。第（1_2）集_梦幻西游2_游戏资讯 - Google Chrome 2022-09-29 22-14-24.mp4"
with open(file_path, "rb") as fp:
    data = fp.read()
    node = parse_nodes(data)
print(node)