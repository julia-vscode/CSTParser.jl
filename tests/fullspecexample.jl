module ModuleName
using ModuleName
using ModuleName.SubModuleName
importall ModuleName
import ModuleName
import ModuleName: FunctionName1, FunctionName2
import ModuleName.SubModuleName

export FunctionName1

const Const = 1

function FunctionName end

function FunctionName(arg1::Type1)
    return ReturnName
end

function FunctionName(arg1, arg2::Type1, arg3::Type1{Type2}, arg4::Type3{Type1}, arg5 = default, arg2::Type1 = default)

    return ReturnName
end


end