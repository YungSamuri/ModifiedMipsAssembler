import sys

def main():
    # Defining the assembly file to read from
    filename = "input.asm"
    if (len(sys.argv) > 1):
        filename = sys.argv[1]
    
    # Read all lines from the assembly file, and store them in a list
    with open(filename, "r") as infile:
        lines = infile.readlines()
    
    # Step 1: Preprocess the lines to remove comments and whitespace
    lines = preprocess_lines(lines)
    
    # Step 2: Use the preprocessed program to build data table
    data_table, data_list, lines = build_data_table(lines)
    
    # Step 3: Build a label table and strip out the labels from the code
    label_table, lines = build_label_table(lines)
    
    # Step 4: Encode the program into a list of binary strings
    encoded_program = encode_program(lines, label_table, data_table)
    
    binary = False
    extension = "hex"
    
    if (len(sys.argv) > 2 and sys.argv[2] == "-b"):
        binary = True
        extension = "bin"
        
    
    # Step 5: Convert the strings to hexadecimal and write them to a file
    hex_program = post_process(encoded_program, binary)
    with open(f"output.{extension}", "w") as outfile:
        outfile.write("v3.0 hex words addressed\n00: ")
        outfile.writelines(hex_program)
    
    # Step 6: Convert the data list to hexadecimal and write it to a file
    with open(f"data.{extension}", "w") as outfile:
        outfile.write("v3.0 hex words addressed\n00: ")
        if binary:
            outfile.writelines([f"{int(d):016b} " for d in data_list])
        else:
            outfile.writelines([f"{int(d):04x} " for d in data_list])
    
    
def preprocess_lines(lines):            
    ret = []
    for line in lines:
        line = line.split("#")[0]
        line = line.strip()
        if line != "":
            ret.append(line)
        
    return ret


def build_data_table(lines):
    if lines[0] == ".text":
        return {}, [], lines[1:]
    elif lines[0] != ".data":
        return {}, [], lines
    
    lines = lines[1:]
    
    ret = []
    data_table = {}
    data_list = []
    
    for i in range(len(lines)):
        if lines[i] == ".text":
            ret = lines[i + 1:]
            break
        
        data_table[lines[i].split(":")[0]] = i
        data_list.append(lines[i].split()[1])
        
    return data_table, data_list, ret


def build_label_table(lines):
    ret = []
    label_table = {}
    i = 0
    
    for line in lines:
        if ":" in line:
            label_table[line.split(":")[0]] = i
        else:
            ret.append(line)
            i += 1
            
    return label_table, ret


def encode_program(lines, label_table, data_table):
    encoded_program = []
    
    for i in range(len(lines)):
        line = encode_instruction(i, lines[i], label_table, data_table)
        encoded_program.append(line)
        
    return encoded_program


def encode_instruction(line_num, instruction, label_table, data_table):
    encoded_instruction = ""
    instruction = instruction.replace(",", " ")
    instruction = instruction.split()
    try:
        match instruction:
            case [op, rd, rs, rt]:
                match op:
                    case "add":
                        encoded_instruction = f"0000 {register_to_binary(rs)} {register_to_binary(rt)} {register_to_binary(rd)} 010"    
                    case "sub":
                        encoded_instruction = f"0000 {register_to_binary(rs)} {register_to_binary(rt)} {register_to_binary(rd)} 110"    
                    case "and":
                        encoded_instruction = f"0000 {register_to_binary(rs)} {register_to_binary(rt)} {register_to_binary(rd)} 000"    
                    case "or":
                        encoded_instruction = f"0000 {register_to_binary(rs)} {register_to_binary(rt)} {register_to_binary(rd)} 001"    
                    case "slt":
                        encoded_instruction = f"0000 {register_to_binary(rs)} {register_to_binary(rt)} {register_to_binary(rd)} 111"    
                    case "beq" | "bne":
                        op = "0011" if op == "beq" else "0110"
                        offset = label_table[rt] - line_num - 1
                        encoded_instruction = f"{op} {register_to_binary(rs)} {register_to_binary(rd)} {dec_to_bin(offset, 6)}"
                    case "addi":
                        encoded_instruction = f"0101 {register_to_binary(rs)} {register_to_binary(rd)} {dec_to_bin(rt, 6)}"
                    case _:
                        raise ValueError("Invalid syntax")
            case [op, rs, immediate]:
                match op:
                    case "lw" | "sw":
                        op = "0001" if op == "lw" else "0010"
                        if "(" in immediate:
                            register = immediate.split("(")[1]
                            register = register[:-1]
                            immediate = immediate.split("(")[0]
                            encoded_instruction = f"{op} {register_to_binary(register)} {register_to_binary(rs)} {dec_to_bin(immediate, 6)}"
                        else:
                            immediate = data_table[immediate]
                            encoded_instruction = f"{op} 000 {register_to_binary(rs)} {dec_to_bin(immediate, 6)}"
                    case _:
                        raise ValueError("Invalid syntax")
            case [op, address]:
                match op:
                    case "j":
                        op = "0100"
                        address = label_table[address]
                        address = dec_to_bin(address, 12)
                    case "jr":
                        op = "0111"
                        address = register_to_binary(address) + " 000 000 000"
                    case "jal":
                        op = "1000"
                        address = label_table[address]
                        address = dec_to_bin(address, 12)
                    case _:
                        raise ValueError("Invlaid syntax")
                encoded_instruction = f"{op} {address}"
            case ["display"]:
                encoded_instruction = f"1111 000000000000"
            case _:
                raise ValueError("Invalid syntax")
    except ValueError as err:
        print(f"{type(err)} occured assembling line {line_num}: {err.args[0]}")
        exit()
    except Exception as err:
        print(f"{type(err)} occured assembling line {line_num}: Check syntax")
        exit()
            
    return encoded_instruction


def register_to_binary(register):
    register = int(register[1])
    return f"{register:03b}"


def dec_to_bin(num, digits):
    num = int(num)
    if (digits == 6):
        if num >= 0:
            return f"{num:06b}"
        return f"{(1 << 6) + num:06b}"
    if num >= 0:
        return f"{num:012b}"
    return f"{(1 << 12) + num:012b}"


def post_process(lines, binary = False):
    ret = []
    for line in lines:
        line = line.replace(" ", "")
        if binary:
            line = f"{int(line, 2):016b} "
        else:
            line = f"{int(line, 2):04x} "
        ret.append(line) 
    return ret



if __name__ == "__main__":
    main()