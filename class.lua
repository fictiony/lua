--[[
	基本类架构 1.0
	______________________________

	<AClass> = class(name, base)	- 创建类
	class.<AClass>(base){...}		- 创建并定义类（语法糖形式）

	<AClass>:define{...}			- 定义类成员（可多次调用，静态成员名需加"__"前缀）
	<AClass>:extends(base)			- 判断是否从指定类继承
	<AClass>.base					- 父类
	<AClass>.name					- 类名
	<AClass>.m						- 类实例成员表（类实例可直接访问，支持继承和重载）
	<AClass>.<prop>					- 类静态成员（不支持继承）
	<AClass>(...)					- 创建类实例并自动初始化
	<AClass>.ctor(obj, ...)			- 初始化类实例，会自动调用父类ctor（可重载，但需手动调用父类ctor）

	<AObject>:instanceof(cls)		- 判断是否为指定类实例
	<AObject>.class					- 所属类
	<AObject>.<prop>				- 类实例成员（支持继承和重载）
	______________________________

	使用范例：
	require("class")		--引入本模块

	class.A()				--优雅的类定义形式（但目前无法被IDE识别）
	{
		prop = 5,
		__ctor = function( self, prop )
			if prop ~= nil then
				self.prop = prop
			end
			print("A.ctor:", self)
		end,
		method = function( self )
			print(self, "prop =", self.prop)
		end,
	}

	class.B(A)
	{
		prop = 10,
	}
	B:define				--成员定义部分亦可分离
	{
		method = function( self )
			print("B.method begin:", self)
			A.method(self)
			print("B.method end:", self)
		end,
	}

	C = class("C", B)		--传统的定义形式（能被IDE识别，且支持":"语法糖）
	function C:ctor( prop )
		if prop ~= nil then
			B.ctor(self, prop * prop)
		else
			B.ctor(self, self.prop * self.prop)
		end
		print("C.ctor:", self)
	end
	function C.m:method()
		print("C.method begin:", self)
		B.method(self)
		print("C.method end:", self)
	end

	print "a ----------"
	a = A()
	a:method()
	print "a2 ---------"
	a2 = A(8)
	a2:method()
	print "b ----------"
	b = B()
	b:method()
	print "b2 ---------"
	b2 = B(8)
	b2:method()
	print "c ----------"
	c = C()
	c:method()
	print "c2 ---------"
	c2 = C(8)
	c2:method()
	print "------------"
	print("C:extends(A):", C:extends(A))
	print("c:instanceof(A):", c:instanceof(A))
--]]

-------------------------------------------------------

--[[
	定义class关键字（单继承）
--]]
local class = {}
local class_mt = {}
setmetatable(class, class_mt)
_G.class = class

-------------------------------------------------------

--[[
	创建类，name为类名，base为父类
--]]
function class_mt:__call( name, base )
	if type(name) ~= "string" then
		error("Invalid class name: " .. tostring(name))
	elseif base and class_mt.get_proto(base) ~= class_mt.class_proto then
		error("Invalid base class: " .. tostring(base))
	end

	local cls = {}
	cls.ctor = function( ... )
		getmetatable(cls).__meta.ctor(cls, ...)
	end

	local m = {}
	if base then
		setmetatable(m, {__index = base.m})
	end

	local mt =
	{
		__index		= class_mt.class_proto,
		__tostring	= class_mt.class_info,
		__call		= class_mt.new,
		__meta		= class_mt,
		__base		= base,
		__name		= name,
		__m			= m,
	}

	return setmetatable(cls, mt)
end

--[[
	以 class.A(base){...} 的语法糖形式创建并定义类
	等价于 A = class("A", base); A:define({...})
--]]
function class_mt:__index( name )
	return function( base )
		local cls = class(name, base)
		getfenv()[name] = cls

		return function( ... )
			cls:define(...)
		end
	end
end

-------------------------------------------------------

--[[
	类原型（原型相同才能继承）
--]]
function class_mt.class_proto( cls, prop )
	local mt = getmetatable(cls)
	if prop == "define" then		return mt.__meta.define
	elseif prop == "extends" then	return mt.__meta.extends
	elseif prop == "base" then		return mt.__base
	elseif prop == "name" then		return mt.__name
	elseif prop == "m" then			return mt.__m
	else							return mt.__m[prop]
	end
end

--[[
	获取类原型（原型相同的类才能继承）
--]]
function class_mt.get_proto( cls )
	local mt = getmetatable(cls)
	return mt and mt.__index
end

--[[
	获取类说明
--]]
function class_mt.class_info( cls )
	return "[class " .. cls.name .. "]"
end

--[[
	定义类实例成员，每个参数为一组（需为table），静态成员名需加"__"前缀
--]]
function class_mt.define( cls, ... )
	local members = cls.m
	for i, group in ipairs({...}) do
		if type(group) ~= "table" then
			error("Member group [" .. i .. "] should be a table: " .. tostring(group))
		end

		for k, v in pairs(group) do
			if k:sub(1, 2) == "__" then
				rawset(cls, k:sub(3), v)
			else
				rawset(members, k, v)
			end
		end
	end
end

--[[
	判断是否从指定类继承
--]]
function class_mt.extends( cls, base )
	local cls_base = cls.base
	return cls_base ~= nil and (cls_base == base or cls_base:extends(base))
end

--[[
	创建类实例并自动初始化
--]]
function class_mt.new( cls, ... )
	local mata = getmetatable(cls).__meta

	local mt =
	{
		__index		= mata.object_proto,
		__tostring	= mata.object_info,
		__class		= cls,
	}
	local obj = setmetatable({}, mt)

	cls.ctor(obj, ...)
	return obj
end

--[[
	初始化类实例，会自动调用父类ctor
--]]
function class_mt.ctor( cls, ... )
	local cls_base = cls.base
	if cls_base then
		cls_base.ctor(...)
	end
end

-------------------------------------------------------

--[[
	对象原型
--]]
function class_mt.object_proto( obj, prop )
	local cls = getmetatable(obj).__class
	if prop == "instanceof" then	return getmetatable(cls).__meta.instanceof
	elseif prop == "class" then		return cls
	else							return cls.m[prop]
	end
end

--[[
	获取对象说明
--]]
function class_mt.object_info( obj )
	return "[object " .. obj.class.name .. "]"
end

--[[
	判断是否为指定类实例
--]]
function class_mt.instanceof( obj, cls )
	local obj_cls = obj.class
	return obj_cls ~= nil and (obj_cls == cls or obj_cls:extends(cls))
end

-------------------------------------------------------

return class
