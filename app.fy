import streamlit as st
import pandas as pd
import plotly.express as px
import os
from datetime import date

# =========================
# CẤU HÌNH TRANG
# =========================

st.set_page_config(
    page_title="Travel Tour Management",
    page_icon="✈️",
    layout="wide"
)

# =========================
# KHỞI TẠO DỮ LIỆU
# =========================

DATA_DIR = "data"

os.makedirs(DATA_DIR, exist_ok=True)

TOUR_FILE = f"{DATA_DIR}/tours.csv"
CUSTOMER_FILE = f"{DATA_DIR}/customers.csv"
BOOKING_FILE = f"{DATA_DIR}/bookings.csv"


def load_data(file, columns):

    if os.path.exists(file):
        return pd.read_csv(file)

    df = pd.DataFrame(columns=columns)
    df.to_csv(file, index=False)

    return df


tours = load_data(
    TOUR_FILE,
    [
        "tour_id",
        "tour_name",
        "destination",
        "start_date",
        "end_date",
        "duration",
        "price",
        "max_people"
    ]
)

customers = load_data(
    CUSTOMER_FILE,
    [
        "customer_id",
        "name",
        "phone",
        "email"
    ]
)

bookings = load_data(
    BOOKING_FILE,
    [
        "booking_id",
        "customer_id",
        "tour_id",
        "booking_date",
        "people",
        "total"
    ]
)


# =========================
# HÀM LƯU DỮ LIỆU
# =========================

def save_data():

    tours.to_csv(TOUR_FILE, index=False)
    customers.to_csv(CUSTOMER_FILE, index=False)
    bookings.to_csv(BOOKING_FILE, index=False)


# =========================
# SIDEBAR
# =========================

st.sidebar.title("✈️ TRAVEL TOUR")

st.sidebar.caption("Hệ thống quản lý tour trọn gói")

menu = st.sidebar.radio(
    "MENU",
    [
        "🏠 Dashboard",
        "🗺️ Quản lý tour",
        "👥 Khách hàng",
        "📋 Booking",
        "💰 Hóa đơn",
        "📊 Báo cáo"
    ]
)


# =========================
# DASHBOARD
# =========================

if menu == "🏠 Dashboard":

    st.title("🏠 Dashboard")

    st.write(
        "Tổng quan hoạt động kinh doanh tour"
    )

    total_tours = len(tours)
    total_customers = len(customers)
    total_bookings = len(bookings)

    if len(bookings) > 0:
        revenue = bookings["total"].sum()
    else:
        revenue = 0

    col1, col2, col3, col4 = st.columns(4)

    col1.metric(
        "🗺️ Tổng số tour",
        total_tours
    )

    col2.metric(
        "👥 Khách hàng",
        total_customers
    )

    col3.metric(
        "📋 Booking",
        total_bookings
    )

    col4.metric(
        "💰 Doanh thu",
        f"{revenue:,.0f} VNĐ"
    )

    st.divider()

    st.subheader("📋 Booking gần đây")

    if len(bookings) > 0:

        st.dataframe(
            bookings.tail(10),
            use_container_width=True
        )

    else:

        st.info(
            "Chưa có booking nào."
        )


# =========================
# QUẢN LÝ TOUR
# =========================

elif menu == "🗺️ Quản lý tour":

    st.title("🗺️ Quản lý tour")

    tab1, tab2 = st.tabs(
        [
            "📋 Danh sách tour",
            "➕ Tạo tour"
        ]
    )

    # -------------------------
    # DANH SÁCH TOUR
    # -------------------------

    with tab1:

        if len(tours) > 0:

            st.dataframe(
                tours,
                use_container_width=True
            )

        else:

            st.info(
                "Chưa có tour nào."
            )

    # -------------------------
    # TẠO TOUR
    # -------------------------

    with tab2:

        st.subheader(
            "➕ Tạo tour mới"
        )

        with st.form("tour_form"):

            tour_name = st.text_input(
                "Tên tour"
            )

            destination = st.text_input(
                "Điểm đến"
            )

            col1, col2 = st.columns(2)

            with col1:

                start_date = st.date_input(
                    "Ngày khởi hành"
                )

            with col2:

                end_date = st.date_input(
                    "Ngày kết thúc"
                )

            duration = st.number_input(
                "Số ngày",
                min_value=1,
                value=3
            )

            col3, col4 = st.columns(2)

            with col3:

                price = st.number_input(
                    "Giá tour / khách",
                    min_value=0,
                    step=100000
                )

            with col4:

                max_people = st.number_input(
                    "Số khách tối đa",
                    min_value=1,
                    value=40
                )

            submit = st.form_submit_button(
                "💾 Lưu tour"
            )

            if submit:

                if tour_name == "" or destination == "":

                    st.error(
                        "Vui lòng nhập đầy đủ thông tin."
                    )

                else:

                    new_id = (
                        f"T{len(tours) + 1:03d}"
                    )

                    new_tour = pd.DataFrame(
                        [{
                            "tour_id": new_id,
                            "tour_name": tour_name,
                            "destination": destination,
                            "start_date": start_date,
                            "end_date": end_date,
                            "duration": duration,
                            "price": price,
                            "max_people": max_people
                        }]
                    )

                    tours = pd.concat(
                        [tours, new_tour],
                        ignore_index=True
                    )

                    save_data()

                    st.success(
                        f"Đã tạo tour {new_id}!"
                    )

                    st.rerun()


# =========================
# KHÁCH HÀNG
# =========================

elif menu == "👥 Khách hàng":

    st.title("👥 Quản lý khách hàng")

    tab1, tab2 = st.tabs(
        [
            "📋 Danh sách",
            "➕ Thêm khách"
        ]
    )

    with tab1:

        if len(customers) > 0:

            st.dataframe(
                customers,
                use_container_width=True
            )

        else:

            st.info(
                "Chưa có khách hàng."
            )

    with tab2:

        with st.form("customer_form"):

            name = st.text_input(
                "Họ và tên"
            )

            phone = st.text_input(
                "Số điện thoại"
            )

            email = st.text_input(
                "Email"
            )

            submit = st.form_submit_button(
                "💾 Lưu khách hàng"
            )

            if submit:

                if name == "" or phone == "":

                    st.error(
                        "Vui lòng nhập họ tên và số điện thoại."
                    )

                else:

                    new_id = (
                        f"C{len(customers) + 1:03d}"
                    )

                    new_customer = pd.DataFrame(
                        [{
                            "customer_id": new_id,
                            "name": name,
                            "phone": phone,
                            "email": email
                        }]
                    )

                    customers = pd.concat(
                        [
                            customers,
                            new_customer
                        ],
                        ignore_index=True
                    )

                    save_data()

                    st.success(
                        "Đã thêm khách hàng!"
                    )

                    st.rerun()


# =========================
# BOOKING
# =========================

elif menu == "📋 Booking":

    st.title("📋 Quản lý Booking")

    if len(tours) == 0:

        st.warning(
            "Bạn cần tạo tour trước."
        )

    elif len(customers) == 0:

        st.warning(
            "Bạn cần tạo khách hàng trước."
        )

    else:

        with st.form("booking_form"):

            customer_options = dict(
                zip(
                    customers["customer_id"],
                    customers["name"]
                )
            )

            tour_options = dict(
                zip(
                    tours["tour_id"],
                    tours["tour_name"]
                )
            )

            customer_id = st.selectbox(
                "Khách hàng",
                options=list(
                    customer_options.keys()
                ),
                format_func=lambda x:
                f"{x} - {customer_options[x]}"
            )

            tour_id = st.selectbox(
                "Tour",
                options=list(
                    tour_options.keys()
                ),
                format_func=lambda x:
                f"{x} - {tour_options[x]}"
            )

            people = st.number_input(
                "Số người",
                min_value=1,
                value=1
            )

            submit = st.form_submit_button(
                "📋 Tạo Booking"
            )

            if submit:

                tour = tours[
                    tours["tour_id"] == tour_id
                ].iloc[0]

                price = float(
                    tour["price"]
                )

                total = price * people

                booking_id = (
                    f"B{len(bookings) + 1:03d}"
                )

                new_booking = pd.DataFrame(
                    [{
                        "booking_id": booking_id,
                        "customer_id": customer_id,
                        "tour_id": tour_id,
                        "booking_date": date.today(),
                        "people": people,
                        "total": total
                    }]
                )

                bookings = pd.concat(
                    [
                        bookings,
                        new_booking
                    ],
                    ignore_index=True
                )

                save_data()

                st.success(
                    f"Đã tạo Booking {booking_id}"
                )

                st.rerun()

    st.divider()

    st.subheader(
        "📋 Danh sách Booking"
    )

    if len(bookings) > 0:

        st.dataframe(
            bookings,
            use_container_width=True
        )


# =========================
# HÓA ĐƠN
# =========================

elif menu == "💰 Hóa đơn":

    st.title("💰 Hóa đơn")

    if len(bookings) == 0:

        st.info(
            "Chưa có booking."
        )

    else:

        booking_id = st.selectbox(
            "Chọn Booking",
            bookings["booking_id"]
        )

        booking = bookings[
            bookings["booking_id"] == booking_id
        ].iloc[0]

        customer_id = booking["customer_id"]
        tour_id = booking["tour_id"]

        customer = customers[
            customers["customer_id"] == customer_id
        ]

        tour = tours[
            tours["tour_id"] == tour_id
        ]

        customer_name = (
            customer.iloc[0]["name"]
            if len(customer) > 0
            else "Không xác định"
        )

        tour_name = (
            tour.iloc[0]["tour_name"]
            if len(tour) > 0
            else "Không xác định"
        )

        st.subheader(
            "🧾 HÓA ĐƠN DỊCH VỤ DU LỊCH"
        )

        col1, col2 = st.columns(2)

        with col1:

            st.write(
                f"**Mã Booking:** {booking_id}"
            )

            st.write(
                f"**Khách hàng:** {customer_name}"
            )

        with col2:

            st.write(
                f"**Tour:** {tour_name}"
            )

            st.write(
                f"**Số khách:** {booking['people']}"
            )

        st.divider()

        st.write(
            f"**Tổng thanh toán:** "
            f"{booking['total']:,.0f} VNĐ"
        )

        st.success(
            "Trạng thái: Chờ thanh toán"
        )


# =========================
# BÁO CÁO
# =========================

elif menu == "📊 Báo cáo":

    st.title("📊 Báo cáo kinh doanh")

    if len(bookings) == 0:

        st.info(
            "Chưa có dữ liệu để thống kê."
        )

    else:

        report = bookings.copy()

        report["total"] = pd.to_numeric(
            report["total"]
        )

        revenue = report["total"].sum()

        customers_count = report["people"].sum()

        col1, col2 = st.columns(2)

        col1.metric(
            "💰 Tổng doanh thu",
            f"{revenue:,.0f} VNĐ"
        )

        col2.metric(
            "👥 Tổng lượt khách",
            customers_count
        )

        st.divider()

        revenue_by_tour = (
            report
            .groupby("tour_id")["total"]
            .sum()
            .reset_index()
        )

        revenue_by_tour = revenue_by_tour.merge(
            tours[
                ["tour_id", "tour_name"]
            ],
            on="tour_id",
            how="left"
        )

        fig = px.bar(
            revenue_by_tour,
            x="tour_name",
            y="total",
            title="Doanh thu theo tour"
        )

        st.plotly_chart(
            fig,
            use_container_width=True
        )
