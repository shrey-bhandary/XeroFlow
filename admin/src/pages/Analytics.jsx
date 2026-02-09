import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import {
    IndianRupee,
    TrendingUp,
    ShoppingBag,
    Calendar,
    Download,
    BarChart3,
    PieChart,
    ArrowUp,
    ArrowDown
} from 'lucide-react'

export default function Analytics() {
    const [dateRange, setDateRange] = useState('week')
    const [stats, setStats] = useState({
        totalRevenue: 0,
        totalOrders: 0,
        avgOrderValue: 0,
        completionRate: 0
    })
    const [dailyData, setDailyData] = useState([])
    const [optionStats, setOptionStats] = useState({
        colorVsBw: { color: 0, bw: 0 },
        paperSizes: {},
        doubleSided: { single: 0, double: 0 }
    })
    const [loading, setLoading] = useState(true)

    const dateRanges = [
        { id: 'today', label: 'Today' },
        { id: 'week', label: 'This Week' },
        { id: 'month', label: 'This Month' },
        { id: 'all', label: 'All Time' }
    ]

    useEffect(() => {
        fetchAnalytics()
    }, [dateRange])

    const getDateFilter = () => {
        const now = new Date()
        switch (dateRange) {
            case 'today':
                return now.toISOString().split('T')[0]
            case 'week':
                const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
                return weekAgo.toISOString()
            case 'month':
                const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
                return monthAgo.toISOString()
            default:
                return null
        }
    }

    const fetchAnalytics = async () => {
        setLoading(true)
        try {
            let query = supabase
                .from('orders')
                .select('*')

            const dateFilter = getDateFilter()
            if (dateFilter) {
                query = query.gte('created_at', dateFilter)
            }

            const { data: orders, error } = await query

            if (error) throw error

            // Calculate stats
            const completedOrders = orders.filter(o => o.status === 'completed')
            const totalRevenue = completedOrders.reduce((sum, o) => sum + Number(o.cost), 0)

            setStats({
                totalRevenue,
                totalOrders: orders.length,
                avgOrderValue: orders.length > 0 ? totalRevenue / completedOrders.length || 0 : 0,
                completionRate: orders.length > 0 ? (completedOrders.length / orders.length * 100).toFixed(1) : 0
            })

            // Calculate daily revenue
            const dailyRevenue = {}
            orders.forEach(order => {
                const date = order.created_at.split('T')[0]
                if (!dailyRevenue[date]) {
                    dailyRevenue[date] = { revenue: 0, orders: 0 }
                }
                dailyRevenue[date].orders++
                if (order.status === 'completed') {
                    dailyRevenue[date].revenue += Number(order.cost)
                }
            })

            const sortedDates = Object.entries(dailyRevenue)
                .sort((a, b) => a[0].localeCompare(b[0]))
                .slice(-7)
            setDailyData(sortedDates)

            // Calculate option stats
            const colorCount = orders.filter(o => o.is_color).length
            const doubleCount = orders.filter(o => o.is_double_sided).length
            const paperSizes = {}
            orders.forEach(order => {
                const size = order.paper_size || 'A4'
                paperSizes[size] = (paperSizes[size] || 0) + 1
            })

            setOptionStats({
                colorVsBw: {
                    color: colorCount,
                    bw: orders.length - colorCount
                },
                paperSizes,
                doubleSided: {
                    single: orders.length - doubleCount,
                    double: doubleCount
                }
            })

        } catch (error) {
            console.error('Error fetching analytics:', error)
        } finally {
            setLoading(false)
        }
    }

    const formatDate = (dateString) => {
        const date = new Date(dateString)
        return date.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
    }

    const exportCSV = () => {
        // Generate CSV of daily data
        const headers = ['Date', 'Orders', 'Revenue']
        const rows = dailyData.map(([date, data]) =>
            [date, data.orders, data.revenue]
        )

        const csv = [headers, ...rows].map(row => row.join(',')).join('\n')
        const blob = new Blob([csv], { type: 'text/csv' })
        const url = URL.createObjectURL(blob)

        const a = document.createElement('a')
        a.href = url
        a.download = `xeroflow-analytics-${dateRange}.csv`
        a.click()
    }

    if (loading) {
        return (
            <div className="loading-container">
                <div className="loading-spinner"></div>
            </div>
        )
    }

    const maxRevenue = Math.max(...dailyData.map(([, d]) => d.revenue), 1)

    return (
        <div className="fade-in">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <div>
                    <h1 style={{ fontSize: '24px', fontWeight: '700', marginBottom: '4px' }}>Analytics</h1>
                    <p style={{ color: 'var(--text-secondary)', fontSize: '14px' }}>Track revenue and order insights</p>
                </div>
                <button className="btn btn-secondary" onClick={exportCSV}>
                    <Download size={16} />
                    Export CSV
                </button>
            </div>

            {/* Date Range Tabs */}
            <div className="tabs" style={{ marginBottom: '24px' }}>
                {dateRanges.map(range => (
                    <button
                        key={range.id}
                        className={`tab ${dateRange === range.id ? 'active' : ''}`}
                        onClick={() => setDateRange(range.id)}
                    >
                        {range.label}
                    </button>
                ))}
            </div>

            {/* Stats Grid */}
            <div className="stats-grid">
                <div className="stat-card">
                    <div className="stat-icon purple">
                        <IndianRupee size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>₹{stats.totalRevenue.toLocaleString()}</h3>
                        <p>Total Revenue</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon blue">
                        <ShoppingBag size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>{stats.totalOrders}</h3>
                        <p>Total Orders</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon orange">
                        <TrendingUp size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>₹{Math.round(stats.avgOrderValue).toLocaleString()}</h3>
                        <p>Avg Order Value</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon green">
                        <BarChart3 size={24} />
                    </div>
                    <div className="stat-info">
                        <h3>{stats.completionRate}%</h3>
                        <p>Completion Rate</p>
                    </div>
                </div>
            </div>

            {/* Charts Row */}
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '20px', marginBottom: '20px' }}>
                {/* Daily Revenue Chart */}
                <div className="card">
                    <div className="card-header">
                        <h2>Daily Revenue</h2>
                    </div>

                    {dailyData.length === 0 ? (
                        <div className="empty-state">
                            <BarChart3 size={48} />
                            <h3>No data available</h3>
                            <p>Revenue data will appear here</p>
                        </div>
                    ) : (
                        <div style={{ display: 'flex', alignItems: 'flex-end', gap: '12px', height: '200px', paddingTop: '20px' }}>
                            {dailyData.map(([date, data]) => (
                                <div
                                    key={date}
                                    style={{
                                        flex: 1,
                                        display: 'flex',
                                        flexDirection: 'column',
                                        alignItems: 'center',
                                        gap: '8px'
                                    }}
                                >
                                    <div
                                        style={{
                                            width: '100%',
                                            height: `${(data.revenue / maxRevenue) * 150}px`,
                                            minHeight: '4px',
                                            background: 'linear-gradient(180deg, var(--primary-blue), var(--dark-blue))',
                                            borderRadius: '4px 4px 0 0',
                                            transition: 'height 0.3s ease'
                                        }}
                                        title={`₹${data.revenue.toLocaleString()}`}
                                    ></div>
                                    <div style={{ textAlign: 'center' }}>
                                        <div style={{ fontSize: '11px', fontWeight: '600', color: 'var(--text-primary)' }}>
                                            ₹{data.revenue.toLocaleString()}
                                        </div>
                                        <div style={{ fontSize: '10px', color: 'var(--text-muted)' }}>
                                            {formatDate(date)}
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>

                {/* Print Options Distribution */}
                <div className="card">
                    <div className="card-header">
                        <h2>Print Options</h2>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                        {/* Color vs B&W */}
                        <div>
                            <div style={{ fontSize: '13px', fontWeight: '500', marginBottom: '8px', color: 'var(--text-secondary)' }}>
                                Color vs B&W
                            </div>
                            <div style={{ display: 'flex', gap: '4px', height: '24px', borderRadius: '12px', overflow: 'hidden' }}>
                                <div
                                    style={{
                                        flex: optionStats.colorVsBw.color || 0.1,
                                        background: 'var(--primary-orange)',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        fontSize: '11px',
                                        fontWeight: '600',
                                        color: 'white'
                                    }}
                                >
                                    {optionStats.colorVsBw.color}
                                </div>
                                <div
                                    style={{
                                        flex: optionStats.colorVsBw.bw || 0.1,
                                        background: 'var(--text-muted)',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        fontSize: '11px',
                                        fontWeight: '600',
                                        color: 'white'
                                    }}
                                >
                                    {optionStats.colorVsBw.bw}
                                </div>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '4px' }}>
                                <span style={{ fontSize: '11px', color: 'var(--primary-orange)' }}>Color</span>
                                <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>B&W</span>
                            </div>
                        </div>

                        {/* Paper Sizes */}
                        <div>
                            <div style={{ fontSize: '13px', fontWeight: '500', marginBottom: '8px', color: 'var(--text-secondary)' }}>
                                Paper Sizes
                            </div>
                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                                {Object.entries(optionStats.paperSizes).map(([size, count]) => (
                                    <span
                                        key={size}
                                        className="detail-tag"
                                        style={{ background: 'var(--bg-primary)' }}
                                    >
                                        {size}: {count}
                                    </span>
                                ))}
                            </div>
                        </div>

                        {/* Single vs Double-sided */}
                        <div>
                            <div style={{ fontSize: '13px', fontWeight: '500', marginBottom: '8px', color: 'var(--text-secondary)' }}>
                                Sided Printing
                            </div>
                            <div style={{ display: 'flex', gap: '4px', height: '24px', borderRadius: '12px', overflow: 'hidden' }}>
                                <div
                                    style={{
                                        flex: optionStats.doubleSided.single || 0.1,
                                        background: 'var(--primary-blue)',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        fontSize: '11px',
                                        fontWeight: '600',
                                        color: 'white'
                                    }}
                                >
                                    {optionStats.doubleSided.single}
                                </div>
                                <div
                                    style={{
                                        flex: optionStats.doubleSided.double || 0.1,
                                        background: 'var(--light-blue)',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        fontSize: '11px',
                                        fontWeight: '600',
                                        color: 'white'
                                    }}
                                >
                                    {optionStats.doubleSided.double}
                                </div>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '4px' }}>
                                <span style={{ fontSize: '11px', color: 'var(--primary-blue)' }}>Single</span>
                                <span style={{ fontSize: '11px', color: 'var(--light-blue)' }}>Double</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}
