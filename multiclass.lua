--[[
	多继承类架构 1.0
	______________________________

	<AClass> = multiclass(name, ...)	- 创建类（可指定多个父类）
	multiclass.<AClass>(...){...}		- 创建并定义类（语法糖形式）

	<AClass>:define{...}		    	- 定义类成员（可多次调用，静态成员名需加"__"前缀）
	<AClass>:extends(base)		    	- 判断是否从指定类继承
	<AClass>.base				    	- 父类（多继承时为列表）
	<AClass>.name				    	- 类名
	<AClass>.m					    	- 类实例成员表（类实例可直接访问，支持继承和重载，多继承存在歧义时取首项）
	<AClass>.<prop>				    	- 类静态成员（不支持继承）
	<AClass>(...)				    	- 创建类实例并自动初始化
	<AClass>.ctor(obj, ...)			    - 初始化类实例，会自动调用所有父类的ctor（可重载，但需手动调用每个父类的ctor）

	<AObject>:instanceof(cls)		    - 判断是否为指定类实例
	<AObject>.class					    - 所属类
	<AObject>.<prop>				    - 类实例成员（支持继承和重载，多继承存在歧义时取首项）
	______________________________

	使用范例：
	require("multiclass")		--引入本模块

	class.A()					--父类A
	{
		__ctor = function( self )
			print("A.ctor:", self)
		end,
		test = function( self )
			print("A.test:", self)
		end,
	}
	multiclass.B()				--父类B（不为多继承时，等价于class）
	{
		__ctor = function( self )
			print("B.ctor:", self)
		end,
		test = function( self )
			print("B.test:", self)
		end,
	}
	multiclass.C(A, B)			--多继承，使用默认ctor，并重载test
	{
		test = function( self )
			B.test(self)
			A.test(self)
			print("C.test:", self)
		end,
	}

	a = A()
	a:test()
	b = B()
	b:test()
	c = C()
	c:test()
--]]

-------------------------------------------------------

--[[
	定义multiclass关键字（多继承）
--]]
local class_mt = getmetatable(require "class")
local multiclass = {}
local multiclass_mt = {}
setmetatable(multiclass, multiclass_mt)
setmetatable(multiclass_mt, {__index = class_mt})
_G.multiclass = multiclass

-------------------------------------------------------

--[[
	创建类（可指定多个父类）
--]]
function multiclass_mt:__call( name, base, ... )
	local bases = ... and {base, ...} or nil
	local cls = class_mt:__call(name, bases and nil or base)

	if bases then
		for _, i in ipairs(bases) do
			if class_mt.get_proto(i) ~= class_mt.class_proto then
				error("Invalid base class: " .. tostring(i))
			end
		end

		local mt = getmetatable(cls)		--多继承时重定向
		mt.__meta = multiclass_mt
		mt.__base = bases

		local m_mt =
		{
			__index		= multiclass_mt.get_member,
			__class		= cls,
		}
		setmetatable(mt.__m, m_mt)
	end

	return cls
end

--[[
	以 multiclass.A(...){...} 的语法糖形式创建并定义类
	等价于 A = multiclass("A", ...); A:define({...})
--]]
function multiclass_mt:__index( name )
	return function( ... )
		local cls = multiclass(name, ...)
		getfenv()[name] = cls

		return function( ... )
			cls:define(...)
		end
	end
end

-------------------------------------------------------

--[[
	判断是否从指定类继承
--]]
function multiclass_mt.extends( cls, base )
	local cls_base = cls.base
    if cls_base then

        if getmetatable(cls_base) then      --单个父类
            return cls_base == base or cls_base:extends(base)
        end

        for _, i in ipairs(cls_base) do     --多个父类
            if i == base or i:extends(base) then
                return true
            end
        end

    end
	return false
end

--[[
	初始化类实例，会自动调用所有父类的ctor
--]]
function multiclass_mt.ctor( cls, ... )
	for _, i in ipairs(cls.base) do
		i.ctor(...)
	end
end

--[[
	获取类实例成员，会遍历所有父类实例成员表
--]]
function multiclass_mt.get_member( m, prop, ... )
	local cls = getmetatable(m).__class

	for _, i in ipairs(cls.base) do
		local member = i.m[prop]
		if member ~= nil then
			return member
		end
	end
end

-------------------------------------------------------

return multiclass