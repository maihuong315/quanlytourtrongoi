import streamlit as st
import mysql.connector
from mysql.connector import Error
import pandas as pd
from datetime import date

# =========================================================
# 1. CẤU HÌNH WEBSITE
# =========================================================

st.set_page_config(
    page_title="Quản lý Tour Trọn Gói",
    page_icon="✈️",
    layout="wide"
)

# =========================================================
# 2. KẾT NỐI MYSQL AIVEN
# =========================================================

def connect_mysql():
    try:
        connection = mysql.connector.connect(
            host="mysql-19728385-npmaihuong-927f.b.aivencloud.com",
            port=27942,
            user="avnadmin",
            password="AVNS_zBDlzsF9I5fC-EdWcl0",
            database="defaultdb",
            ssl_ca="CA_CERTIFICATE"
        )

        return connection

    except Error as e:
        st.error(f"❌ Lỗi kết nối MySQL: {e}")
        return None


# =========================================================
# 3. HÀM ĐỌC DỮ LIỆU
# =========================================================

def read_data(sql, params=None):

    connection = connect_mysql()

    if connection is None:
        return pd.DataFrame()

    try:
        cursor = connection.cursor(dictionary=True)

        cursor.execute(sql, params or ())

        data = cursor.fetchall()

        cursor.close()
        connection.close()

        return pd.DataFrame(data)

    except Error as e:

        st.error(f"Lỗi truy vấn: {e}")

        if connection.is_connected():
            connection.close()

        return pd.DataFrame()


# =========================================================
# 4. HÀM THÊM / SỬA / XÓA DỮ LIỆU
# =========================================================

def execute_query(sql, params=None):

    connection = connect_mysql()

    if connection is None:
        return False

    try:

        cursor = connection.cursor()

        cursor.execute(sql, params or ())

        connection.commit()

        cursor.close()
        connection.close()

        return True

    except Error as e:

        st.error(f"Lỗi database: {e}")

        if connection.is_connected():
            connection.rollback()
            connection.close()

        return False


# =========================================================
# 5. SIDEBAR
# =========================================================

st.sidebar.title("✈️ QUẢN LÝ TOUR")

menu = st.sidebar.radio(
    "MENU",
    [
        "🏠 Tổng quan",
        "🚌 Quản lý Tour",
        "👤 Khách hàng",
        "📋 Đặt Tour",
        "🧾 Hóa đơn",
        "📊 Báo cáo"
    ]
)


# =========================================================
# 6. TRANG TỔNG QUAN
# =========================================================

if menu == "🏠 Tổng quan":

    st.title("✈️ HỆ THỐNG QUẢN LÝ TOUR TRỌN GÓI")

    st.write(
        "Hệ thống hỗ trợ doanh nghiệp lữ hành quản lý "
        "tour, khách hàng, booking và hóa đơn."
    )

    # Lấy dữ liệu

    tours = read_data("SELECT * FROM tours")

    customers = read_data("SELECT * FROM customers")

    bookings = read_data("SELECT * FROM bookings")

    invoices = read_data("SELECT * FROM invoices")

    col1, col2, col3, col4 = st.columns(4)

    with col1:

        st.metric(
            "🚌 Tổng số tour",
            len(tours)
        )

    with col2:

        st.metric(
            "👤 Khách hàng",
            len(customers)
        )

    with col3:

        st.metric(
            "📋 Booking",
            len(bookings)
        )

    with col4:

        if not invoices.empty and "total_amount" in invoices.columns:

            revenue = invoices["total_amount"].sum()

        else:

            revenue = 0

        st.metric(
            "💰 Doanh thu",
            f"{revenue:,.0f} VNĐ"
        )

    st.divider()

    st.subheader("📋 Danh sách tour")

    if not tours.empty:

        st.dataframe(
            tours,
            use_container_width=True
        )

    else:

        st.info("Chưa có dữ liệu tour.")


# =========================================================
# 7. QUẢN LÝ TOUR
# =========================================================

elif menu == "🚌 Quản lý Tour":

    st.title("🚌 QUẢN LÝ TOUR TRỌN GÓI")

    tab1, tab2 = st.tabs(
        [
            "➕ Thêm Tour",
            "📋 Danh sách Tour"
        ]
    )

    # -----------------------------------------------------
    # THÊM TOUR
    # -----------------------------------------------------

    with tab1:

        st.subheader("Thêm tour mới")

        with st.form("add_tour"):

            tour_name = st.text_input(
                "Tên tour"
            )

            destination = st.text_input(
                "Điểm đến"
            )

            start_date = st.date_input(
                "Ngày khởi hành",
                date.today()
            )

            end_date = st.date_input(
                "Ngày kết thúc",
                date.today()
            )

            duration = st.number_input(
                "Số ngày",
                min_value=1,
                value=1
            )

            price = st.number_input(
                "Giá tour / khách (VNĐ)",
                min_value=0,
                step=100000
            )

            max_people = st.number_input(
                "Số khách tối đa",
                min_value=1,
                value=20
            )

            description = st.text_area(
                "Mô tả tour"
            )

            submit = st.form_submit_button(
                "💾 Lưu Tour"
            )

            if submit:

                if tour_name == "" or destination == "":

                    st.warning(
                        "Vui lòng nhập tên tour và điểm đến."
                    )

                else:

                    sql = """
                    INSERT INTO tours
                    (
                        tour_name,
                        destination,
                        start_date,
                        end_date,
                        duration,
                        price,
                        max_people,
                        description
                    )
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                    """

                    success = execute_query(
                        sql,
                        (
                            tour_name,
                            destination,
                            start_date,
                            end_date,
                            duration,
                            price,
                            max_people,
                            description
                        )
                    )

                    if success:

                        st.success(
                            "✅ Thêm tour thành công!"
                        )


    # -----------------------------------------------------
    # DANH SÁCH TOUR
    # -----------------------------------------------------

    with tab2:

        tours = read_data(
            "SELECT * FROM tours ORDER BY tour_id DESC"
        )

        if not tours.empty:

            st.dataframe(
                tours,
                use_container_width=True,
                hide_index=True
            )

        else:

            st.info(
                "Chưa có tour nào."
            )


# =========================================================
# 8. KHÁCH HÀNG
# =========================================================

elif menu == "👤 Khách hàng":

    st.title("👤 QUẢN LÝ KHÁCH HÀNG")

    tab1, tab2 = st.tabs(
        [
            "➕ Thêm khách hàng",
            "📋 Danh sách khách hàng"
        ]
    )

    # -----------------------------------------------------
    # THÊM KHÁCH
    # -----------------------------------------------------

    with tab1:

        with st.form("add_customer"):

            full_name = st.text_input(
                "Họ và tên"
            )

            phone = st.text_input(
                "Số điện thoại"
            )

            email = st.text_input(
                "Email"
            )

            address = st.text_input(
                "Địa chỉ"
            )

            submit = st.form_submit_button(
                "💾 Lưu khách hàng"
            )

            if submit:

                if full_name == "":

                    st.warning(
                        "Vui lòng nhập họ tên."
                    )

                else:

                    sql = """
                    INSERT INTO customers
                    (
                        full_name,
                        phone,
                        email,
                        address
                    )
                    VALUES (%s,%s,%s,%s)
                    """

                    success = execute_query(
                        sql,
                        (
                            full_name,
                            phone,
                            email,
                            address
                        )
                    )

                    if success:

                        st.success(
                            "✅ Thêm khách hàng thành công!"
                        )


    # -----------------------------------------------------
    # DANH SÁCH
    # -----------------------------------------------------

    with tab2:

        customers = read_data(
            """
            SELECT *
            FROM customers
            ORDER BY customer_id DESC
            """
        )

        if not customers.empty:

            st.dataframe(
                customers,
                use_container_width=True,
                hide_index=True
            )

        else:

            st.info(
                "Chưa có khách hàng."
            )


# =========================================================
# 9. ĐẶT TOUR
# =========================================================

elif menu == "📋 Đặt Tour":

    st.title("📋 ĐẶT TOUR")

    customers = read_data(
        """
        SELECT customer_id, full_name
        FROM customers
        ORDER BY full_name
        """
    )

    tours = read_data(
        """
        SELECT
            tour_id,
            tour_name,
            destination,
            price,
            max_people
        FROM tours
        ORDER BY tour_name
        """
    )

    if customers.empty:

        st.warning(
            "⚠️ Chưa có khách hàng. "
            "Hãy thêm khách hàng trước."
        )

    elif tours.empty:

        st.warning(
            "⚠️ Chưa có tour. "
            "Hãy thêm tour trước."
        )

    else:

        customer_list = customers[
            "customer_id"
        ].tolist()

        customer_name_list = customers[
            "full_name"
        ].tolist()

        selected_customer_name = st.selectbox(
            "👤 Chọn khách hàng",
            customer_name_list
        )

        selected_customer_id = customers[
            customers["full_name"]
            == selected_customer_name
        ]["customer_id"].iloc[0]


        tour_name_list = tours[
            "tour_name"
        ].tolist()

        selected_tour_name = st.selectbox(
            "🚌 Chọn tour",
            tour_name_list
        )

        selected_tour = tours[
            tours["tour_name"]
            == selected_tour_name
        ].iloc[0]


        price = float(
            selected_tour["price"]
        )

        max_people = int(
            selected_tour["max_people"]
        )

        st.info(
            f"💰 Giá tour: {price:,.0f} VNĐ/người"
        )

        people = st.number_input(
            "Số lượng khách",
            min_value=1,
            max_value=max_people,
            value=1
        )

        total_amount = price * people

        st.metric(
            "💰 Tổng tiền",
            f"{total_amount:,.0f} VNĐ"
        )

        booking_date = st.date_input(
            "Ngày đặt tour",
            date.today()
        )

        if st.button(
            "✅ Xác nhận đặt tour"
        ):

            # Kiểm tra số khách đã đặt

            check_sql = """
            SELECT COALESCE(SUM(people),0)
            AS booked_people
            FROM bookings
            WHERE tour_id = %s
            """

            booked = read_data(
                check_sql,
                (int(selected_tour["tour_id"]),)
            )

            booked_people = int(
                booked.iloc[0]["booked_people"]
            )

            remaining = max_people - booked_people

            if people > remaining:

                st.error(
                    f"❌ Tour chỉ còn {remaining} chỗ."
                )

            else:

                booking_sql = """
                INSERT INTO bookings
                (
                    customer_id,
                    tour_id,
                    booking_date,
                    people,
                    total_amount
                )
                VALUES (%s,%s,%s,%s,%s)
                """

                success = execute_query(
                    booking_sql,
                    (
                        int(selected_customer_id),
                        int(selected_tour["tour_id"]),
                        booking_date,
                        people,
                        total_amount
                    )
                )

                if success:

                    # Lấy booking ID mới nhất

                    latest_booking = read_data(
                        """
                        SELECT booking_id
                        FROM bookings
                        ORDER BY booking_id DESC
                        LIMIT 1
                        """
                    )

                    booking_id = int(
                        latest_booking.iloc[0]["booking_id"]
                    )

                    # Tạo hóa đơn

                    invoice_sql = """
                    INSERT INTO invoices
                    (
                        booking_id,
                        invoice_date,
                        total_amount,
                        payment_status
                    )
                    VALUES (%s,%s,%s,%s)
                    """

                    execute_query(
                        invoice_sql,
                        (
                            booking_id,
                            booking_date,
                            total_amount,
                            "Chưa thanh toán"
                        )
                    )

                    st.success(
                        "🎉 Đặt tour thành công!"
                    )

                    st.balloons()


# =========================================================
# 10. HÓA ĐƠN
# =========================================================

elif menu == "🧾 Hóa đơn":

    st.title("🧾 QUẢN LÝ HÓA ĐƠN")

    invoices = read_data(
        """
        SELECT
            i.invoice_id,
            i.booking_id,
            i.invoice_date,
            i.total_amount,
            i.payment_status,
            c.full_name,
            t.tour_name
        FROM invoices i
        JOIN bookings b
            ON i.booking_id = b.booking_id
        JOIN customers c
            ON b.customer_id = c.customer_id
        JOIN tours t
            ON b.tour_id = t.tour_id
        ORDER BY i.invoice_id DESC
        """
    )

    if not invoices.empty:

        st.dataframe(
            invoices,
            use_container_width=True,
            hide_index=True
        )

        st.divider()

        invoice_id = st.number_input(
            "Nhập mã hóa đơn cần cập nhật",
            min_value=1,
            step=1
        )

        status = st.selectbox(
            "Trạng thái thanh toán",
            [
                "Chưa thanh toán",
                "Đã đặt cọc",
                "Đã thanh toán"
            ]
        )

        if st.button(
            "💾 Cập nhật thanh toán"
        ):

            success = execute_query(
                """
                UPDATE invoices
                SET payment_status = %s
                WHERE invoice_id = %s
                """,
                (
                    status,
                    invoice_id
                )
            )

            if success:

                st.success(
                    "✅ Cập nhật thành công!"
                )

    else:

        st.info(
            "Chưa có hóa đơn."
        )


# =========================================================
# 11. BÁO CÁO
# =========================================================

elif menu == "📊 Báo cáo":

    st.title("📊 BÁO CÁO DOANH THU")

    report = read_data(
        """
        SELECT
            t.tour_name,
            COUNT(b.booking_id) AS total_bookings,
            COALESCE(
                SUM(b.people),0
            ) AS total_customers,
            COALESCE(
                SUM(b.total_amount),0
            ) AS revenue
        FROM tours t
        LEFT JOIN bookings b
            ON t.tour_id = b.tour_id
        GROUP BY
            t.tour_id,
            t.tour_name
        ORDER BY revenue DESC
        """
    )

    if not report.empty:

        st.subheader(
            "💰 Doanh thu theo tour"
        )

        st.dataframe(
            report,
            use_container_width=True,
            hide_index=True
        )

        st.subheader(
            "📈 Biểu đồ doanh thu"
        )

        chart_data = report.set_index(
            "tour_name"
        )["revenue"]

        st.bar_chart(
            chart_data
        )

        total_revenue = report[
            "revenue"
        ].sum()

        st.metric(
            "💰 Tổng doanh thu",
            f"{total_revenue:,.0f} VNĐ"
        )

    else:

        st.info(
            "Chưa có dữ liệu báo cáo."
        )
