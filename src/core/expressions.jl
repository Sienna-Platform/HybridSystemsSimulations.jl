### Component Abstract Total Reserve Expressions ###
abstract type ComponentReserveExpressionType <: PSI.ExpressionType end
abstract type ComponentServedReserveExpressionType <: PSI.ExpressionType end
abstract type ComponentReserveUpExpressionType <: ComponentReserveExpressionType end
abstract type ComponentReserveDownExpressionType <: ComponentReserveExpressionType end
abstract type ComponentServedReserveUpExpressionType <: ComponentServedReserveExpressionType end
abstract type ComponentServedReserveDownExpressionType <:
              ComponentServedReserveExpressionType end

### Component Total Reserve Expressions ###
struct ThermalReserveUpExpression <: ComponentReserveUpExpressionType end
struct ThermalReserveDownExpression <: ComponentReserveDownExpressionType end
struct RenewableReserveUpExpression <: ComponentReserveUpExpressionType end
struct RenewableReserveDownExpression <: ComponentReserveDownExpressionType end
struct ChargeReserveUpExpression <: ComponentReserveUpExpressionType end
struct ChargeReserveDownExpression <: ComponentReserveDownExpressionType end
struct DischargeReserveUpExpression <: ComponentReserveUpExpressionType end
struct DischargeReserveDownExpression <: ComponentReserveDownExpressionType end

### Component Served Reserve Expressions ###
struct ThermalServedReserveUpExpression <: ComponentServedReserveUpExpressionType end
struct ThermalServedReserveDownExpression <: ComponentServedReserveDownExpressionType end
struct RenewableServedReserveUpExpression <: ComponentServedReserveUpExpressionType end
struct RenewableServedReserveDownExpression <: ComponentServedReserveDownExpressionType end
struct ChargeServedReserveUpExpression <: ComponentServedReserveUpExpressionType end
struct ChargeServedReserveDownExpression <: ComponentServedReserveDownExpressionType end
struct DischargeServedReserveUpExpression <: ComponentServedReserveUpExpressionType end
struct DischargeServedReserveDownExpression <: ComponentServedReserveDownExpressionType end

struct ReserveRangeExpressionLB <: PSI.RangeConstraintLBExpressions end
struct ReserveRangeExpressionUB <: PSI.RangeConstraintUBExpressions end

### Reserve Balance Expression ###
struct ComponentReserveBalanceExpression <: PSI.ExpressionType end
abstract type TotalReserveUpExpression <: PSI.ExpressionType end
abstract type TotalReserveDownExpression <: PSI.ExpressionType end
abstract type ServedReserveUpExpression <: PSI.ExpressionType end
abstract type ServedReserveDownExpression <: PSI.ExpressionType end
struct TotalReserveOutUpExpression <: TotalReserveUpExpression end
struct TotalReserveOutDownExpression <: TotalReserveDownExpression end
struct TotalReserveInUpExpression <: TotalReserveUpExpression end
struct TotalReserveInDownExpression <: TotalReserveDownExpression end
struct ServedReserveInUpExpression <: ServedReserveUpExpression end
struct ServedReserveInDownExpression <: ServedReserveDownExpression end
struct ServedReserveOutUpExpression <: ServedReserveUpExpression end
struct ServedReserveOutDownExpression <: ServedReserveDownExpression end
struct AssetPowerBalance <: PSI.ExpressionType end

PSI.should_write_resulting_value(::Type{<:ComponentServedReserveExpressionType}) = true
