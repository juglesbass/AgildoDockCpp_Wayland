import re

with open('taskbackend.cpp', 'r') as f:
    content = f.read()

# For lines with auto *var = new QProcess(this);
# find them and inject: connect(var, &QProcess::errorOccurred, var, &QObject::deleteLater);

pattern = re.compile(r'(auto\s+\*(\w+)\s*=\s*new\s+QProcess\(this\);)')
def repl(match):
    var_name = match.group(2)
    return match.group(1) + f'\n    connect({var_name}, &QProcess::errorOccurred, {var_name}, &QProcess::deleteLater);'

new_content = pattern.sub(repl, content)

with open('taskbackend.cpp', 'w') as f:
    f.write(new_content)

print("Replaced instances of new QProcess")
